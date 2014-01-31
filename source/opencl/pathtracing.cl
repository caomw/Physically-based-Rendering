#FILE:pt_header.cl:FILE#
#FILE:pt_utils.cl:FILE#
#FILE:pt_spectral.cl:FILE#
#FILE:pt_kdtree.cl:FILE#



/**
 *
 * @param pos
 * @param imageIn
 * @param imageOut
 * @param pixelWeight
 * @param spdLight
 */
void setColors(
	const int2 pos, read_only image2d_t imageIn, write_only image2d_t imageOut,
	const float pixelWeight, float spdLight[40]
) {
	const float4 imagePixel = read_imagef( imageIn, sampler, pos );
	const float4 accumulatedColor = spectrumToRGB( spdLight );
	const float4 color = mix(
		clamp( accumulatedColor, 0.0f, 1.0f ),
		imagePixel, pixelWeight
	);

	write_imagef( imageOut, pos, color );
}



// KERNELS


/**
 * KERNEL.
 * Generate the initial rays into the scene.
 * @param {const uint2}         offset
 * @param {const float4}        initRayParts
 * @param {const global float*} eyeIn          Camera eye position.
 * @param {global float4*}      origins        Output. The origin of each ray. (The camera eye.)
 * @param {global float4*}      dirs           Output. The generated rays for each pixel.
 * @param {const float}         timeSinceStart
 */
kernel void initRays(
	const uint2 offset, const float timeSinceStart,
	const float4 initRayParts, const global float* eyeIn,
	global ray4* rays
) {
	const int2 pos = { offset.x + get_global_id( 0 ), offset.y + get_global_id( 1 ) };

	float4 eye = { eyeIn[0], eyeIn[1], eyeIn[2], 0.0f };
	const float4 w = { eyeIn[3], eyeIn[4], eyeIn[5], 0.0f };
	const float4 u = { eyeIn[6], eyeIn[7], eyeIn[8], 0.0f };
	const float4 v = { eyeIn[9], eyeIn[10], eyeIn[11], 0.0f };

	#ifdef ANTI_ALIASING
		eye += uniformlyRandomVector( timeSinceStart ) * 0.005f;
	#endif

	#define pxWidthAndHeight initRayParts.x
	#define adjustW initRayParts.y
	#define adjustH initRayParts.z
	#define pxwhHalf initRayParts.w

	const uint workIndex = pos.x + pos.y * IMG_WIDTH;
	const float wgsHalfMulPxWH = WORKGROUPSIZE_HALF * pxWidthAndHeight;

	const float4 initialRay = w
			+ wgsHalfMulPxWH * ( v - u )
			+ pxwhHalf * ( u - v )
			+ ( pos.x - adjustW ) * pxWidthAndHeight * u
			- ( WORKGROUPSIZE - pos.y + adjustH ) * pxWidthAndHeight * v;

	ray4 ray;
	ray.origin = eye;
	ray.dir = fast_normalize( initialRay );

	rays[workIndex] = ray;
}


/**
 * KERNEL.
 * Search the kd-tree to find the closest intersection of the ray with a surface.
 * @param {const uint2}              offset
 * @param {const float}              timeSinceStart
 * @param {global float4*}           origins
 * @param {global float4*}           dirs
 * @param {const global float4*}     scNormals
 * @param {const global uint*}       scFacesVN
 * @param {const global kdNonLeaf*}  kdNonLeaves
 * @param {const global kdLeaf*}     kdLeaves
 * @param {const global float*}      kdNodeBB
 * @param {const global int*}        kdNodeFaces
 * @param {global float4*}           hits
 * @param {global float4*}           hitNormals
 */
kernel void pathTracing(
	const uint2 offset, const float timeSinceStart, float pixelWeight,
	const global float4* scVertices, const global uint4* scFaces,
	const global float4* scNormals, const global uint* scFacesVN,
	const global kdNonLeaf* kdNonLeaves, const global kdLeaf* kdLeaves,
	const global uint* kdFaces, const float8 kdRootBB,
	global ray4* rays, const global int* faceToMaterial, const global material* materials,
	const global float* specPowerDists,
	read_only image2d_t imageIn, write_only image2d_t imageOut
) {
	const int2 pos = {
		offset.x + get_global_id( 0 ),
		offset.y + get_global_id( 1 )
	};
	const uint workIndex = pos.x + pos.y * IMG_WIDTH;

	const float4 bbMinRoot = { kdRootBB.s0, kdRootBB.s1, kdRootBB.s2, 0.0f };
	const float4 bbMaxRoot = { kdRootBB.s4, kdRootBB.s5, kdRootBB.s6, 0.0f };

	ray4 explicitRay, newRay;
	ray4 ray = rays[workIndex];
	ray.t = -2.0f;
	ray.nodeIndex = -1;
	ray.faceIndex = -1;

	float entryDistance = 0.0f;
	float exitDistance = FLT_MAX;

	uint bounce, f;
	material mtl, mtlLight;
	float tFar = exitDistance;

	pathPoint path[BOUNCES];
	int pathIndex = 0;

	float4 H, T;
	float t, v, vIn, w;
	float isotropy = 1.0f, roughness;

	if( intersectBoundingBox( ray.origin, ray.dir, bbMinRoot, bbMaxRoot, &entryDistance, &tFar ) ) {
		int startNode = goToLeafNode( 0, kdNonLeaves, fma( entryDistance, ray.dir, ray.origin ) );

		for( bounce = 0; bounce < BOUNCES; bounce++ ) {
			// Find hit surface

			traverseKdTree(
				&ray, startNode, kdNonLeaves, kdLeaves, kdFaces,
				scVertices, scFaces, entryDistance, exitDistance
			);

			if( ray.nodeIndex < 0 ) {
				break;
			}

			f = ray.faceIndex;
			ray.normal = scNormals[scFacesVN[f * 3]];
			mtl = materials[faceToMaterial[f]];
			roughness = 1.0f - mtl.gloss;
			path[pathIndex] = getDefaultPathPoint();

			// Surface tangent orientated along scratches of the material
			T = getT( ray.normal );


			// New direction of the ray (bouncing of the hit surface)

			newRay.t = -2.0f;
			newRay.nodeIndex = -1;
			newRay.faceIndex = -1;

			if( bounce < BOUNCES - 1 ) {
				newRay.origin = fma( ray.t, ray.dir, ray.origin );

				if( mtl.d < 1.0f ) {
					newRay.dir = ray.dir;
				}
				else {
					newRay.dir = ( mtl.illum == 3 )
					           ? fast_normalize(
					             	reflect( ray.dir, ray.normal ) +
					             	uniformlyRandomVector( timeSinceStart + bounce + ray.t ) * mtl.gloss
					             )
					           : fast_normalize(
					             	cosineWeightedDirection( timeSinceStart + bounce + ray.t, ray.normal )
					             );
				}
			}


			// Implicit connection to a light found

			if( mtl.light == 1 ) {
				path[pathIndex].spdLight = mtl.spd;
				pathIndex++;

				break;
			}


			// Try to form explicit connection to a light source

			const float rndNum1 = random( (float4)( 12.9898f, 78.233f, 151.7182f, 0.0f ), timeSinceStart * ray.t + bounce );
			const float rndNum2 = random( (float4)( 63.7264f, 10.873f, 623.6736f, 0.0f ), rndNum1 );

			// float4 lightTarget = (float4)( -0.1f + rndNum1 * 0.2f, 0.2f + rndNum1 * 0.2f, -0.1f + rndNum2 * 0.2f, 0.0f );
			float4 lightTarget = (float4)( -0.5f + rndNum1 * 0.99f, 1.99f, -0.3f + rndNum2 * 0.59f, 0.0f );

			explicitRay.nodeIndex = -1;
			explicitRay.faceIndex = -1;
			explicitRay.t = -2.0f;
			explicitRay.origin = fma( ray.t, ray.dir, ray.origin );
			explicitRay.dir = fast_normalize( lightTarget - explicitRay.origin );

			// if( bounce == BOUNCES - 1 ) {
				traverseKdTree(
					&explicitRay, ray.nodeIndex, kdNonLeaves, kdLeaves, kdFaces,
					scVertices, scFaces, 0.0f, FLT_MAX
				);
			// }

			path[pathIndex].spdMaterial = mtl.spd;

			if( bounce < BOUNCES - 1 ) {
				getValuesBRDF( newRay.dir, -ray.dir, ray.normal, T, &H, &t, &v, &vIn, &w );

				path[pathIndex].D = D( t, v, vIn, w, roughness, isotropy );
				path[pathIndex].u = dot( H, -ray.dir );
				path[pathIndex].lambert = fmax( dot( ray.normal, newRay.dir ), 0.0f );
			}


			if( explicitRay.nodeIndex >= 0 ) {
				material mtlExplicit = materials[faceToMaterial[explicitRay.faceIndex]];

				if( mtlExplicit.light == 1 ) {
					path[pathIndex].spdLight = mtlExplicit.spd;
					getValuesBRDF( explicitRay.dir, -ray.dir, ray.normal, T, &H, &t, &v, &vIn, &w );

					path[pathIndex].D_light = D( t, v, vIn, w, roughness, isotropy );
					path[pathIndex].u_light = dot( H, -ray.dir );
					path[pathIndex].lambert_light = fmax( dot( ray.normal, explicitRay.dir ), 0.0f );
				}
			}


			pathIndex++;
			startNode = ray.nodeIndex;
			ray = newRay;
			entryDistance = 0.0f;
			exitDistance = FLT_MAX;
		}
	}


	float spdLight[40];
	float l1, l2, s, s1, s2;

	for( int i = 0; i < 40; i++ ) {
		spdLight[i] = 0.0f;
	}

	for( int i = pathIndex - 1; i >= 0; i-- ) {
		pathPoint p = path[i];

		// Start of path
		if( i == pathIndex - 1 ) {

			// Implicit path starting at a light source
			if( p.spdMaterial == -1 ) {
				for( int j = 0; j < 40; j++ ) {
					spdLight[j] = specPowerDists[p.spdLight * 40 + j];
				}
			}

			// Explicit path without directly hitting a light source
			else {
				l1 = p.D_light * p.lambert_light;

				for( int j = 0; j < 40; j++ ) {
					s = S( p.u_light, specPowerDists[p.spdMaterial * 40 + j] );
					spdLight[j] = specPowerDists[p.spdLight * 40 + j] * s * l1;
				}
			}

		}
		// The rest of the path to the eye
		else {
			l1 = p.D * p.lambert;
			l2 = p.D_light * p.lambert_light;

			// Point has connection to a light source
			if( p.spdLight >= 0 ) {
				for( int j = 0; j < 40; j++ ) {
					s1 = S( p.u, specPowerDists[p.spdMaterial * 40 + j] ) * l1;
					s2 = S( p.u_light, specPowerDists[p.spdMaterial * 40 + j] ) * l2;
					spdLight[j] = fmax( spdLight[j] * s1, specPowerDists[p.spdLight * 40 + j] * s2 );
				}
			}

			// Point is in the shadow
			else {
				for( int j = 0; j < 40; j++ ) {
					s = S( p.u, specPowerDists[p.spdMaterial * 40 + j] );
					spdLight[j] = spdLight[j] * s * l1;
				}
			}

		}
	}


	setColors( pos, imageIn, imageOut, pixelWeight, spdLight );
}

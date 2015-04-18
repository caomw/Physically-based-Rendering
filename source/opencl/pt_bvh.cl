// Traversal for the acceleration structure.
// Type: Bounding Volume Hierarchy (BVH)

#define CALL_TRAVERSE         traverse( &scene, &ray );
#define CALL_TRAVERSE_SHADOWS traverseShadows( &scene, &lightRay );


/**
 * Test faces of the given node for intersections with the given ray.
 * @param {ray4*}                ray
 * @param {const bvhNode*}       node
 * @param {const global face_t*} faces
 * @param {const float tNear}    tNear
 * @param {float tFar}           tFar
 */
void intersectFaces( const Scene* scene, ray4* ray, const bvhNode* node, const float tNear, float tFar ) {
	float3 tuv;
	float3 normal;


	normal = checkFaceIntersection( scene, ray, node->faces.x, &tuv, tNear, tFar );

	if( ray->t > tuv.x ) {
		ray->normal = normal;
		ray->hitFace = node->faces.x;
		ray->t = tuv.x;
	}

	// Second face, if existing.
	if( node->faces.y == -1 ) {
		return;
	}


	normal = checkFaceIntersection( scene, ray, node->faces.y, &tuv, tNear, tFar );

	if( ray->t > tuv.x ) {
		ray->normal = normal;
		ray->hitFace = node->faces.y;
		ray->t = tuv.x;
	}

	// Third face, if existing.
	if( node->faces.z == -1 ) {
		return;
	}


	normal = checkFaceIntersection( scene, ray, node->faces.z, &tuv, tNear, tFar );

	if( ray->t > tuv.x ) {
		ray->normal = normal;
		ray->hitFace = node->faces.z;
		ray->t = tuv.x;
	}
}


/**
 * Traverse the BVH without using a stack and test the faces against the given ray.
 * @param {global const bvhNode*} bvh
 * @param {ray4*}                 ray
 * @param {global const face_t*}  faces
 */
void traverse( const Scene* scene, ray4* ray ) {
	const float3 invDir = native_recip( ray->dir );
	int index = 0;

	do {
		const bvhNode node = scene->bvh[index];

		float tNear = 0.0f;
		float tFar = INFINITY;

		bool isNodeHit = (
			intersectBox( ray, &invDir, node.bbMin, node.bbMax, &tNear, &tFar ) &&
			tFar > EPSILON5 && ray->t > tNear
		);

		// In case of no hit: Go right or up.
		index = node.faces.w;

		if( !isNodeHit ) {
			continue;
		}

		// Not a leaf node, progress further down to the left.
		if( node.faces.x == -1 ) {
			index = (int) node.bbMin.w;
		}
		// Node is leaf node.
		else {
			intersectFaces( scene, ray, &node, tNear, tFar );
		}
	} while( index > 0 );
}


/**
 * Traverse the BVH and test the faces against the given ray.
 * This version is for the shadow ray test, so it only checks IF there
 * is an intersection and terminates on the first hit.
 * @param {const global bvhNode*} bvh
 * @param {ray4*}                 ray
 * @param {const global face_t*}  faces
 */
void traverseShadows( const Scene* scene, ray4* ray ) {
	const float3 invDir = native_recip( ray->dir );
	int index = 0;

	do {
		const bvhNode node = scene->bvh[index];

		float tNear = 0.0f;
		float tFar = INFINITY;

		bool isNodeHit = (
			intersectBox( ray, &invDir, node.bbMin, node.bbMax, &tNear, &tFar ) &&
			tFar > EPSILON5
		);

		// In case of no hit: Go right or up.
		index = node.faces.w;

		if( !isNodeHit ) {
			continue;
		}

		// Not a leaf node, progress further down to the left.
		if( node.faces.x == -1 ) {
			index = (int) node.bbMin.w;
		}
		// Node is leaf node.
		else {
			intersectFaces( scene, ray, &node, tNear, tFar );

			// It's enough to know that something blocks the way. It doesn't matter what or where.
			// TODO: It *does* matter what and where, if the material has transparency.
			if( ray->t < INFINITY ) {
				break;
			}
		}
	} while( index > 0 );
}

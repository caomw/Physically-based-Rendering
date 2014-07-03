#include "MathHelp.h"


/**
 * Convert an angle from degree to radians.
 * @param  {cl_float} deg Angle in degree.
 * @return {cl_float}     Angle in radians.
 */
cl_float MathHelp::degToRad( cl_float deg ) {
	return ( deg * MH_PI / 180.0f );
}


/**
 * Calculate the bounding box from the given vertices.
 * @param {std::vector<cl_float4>} vertices
 * @param {glm::vec3*}             bbMin
 * @param {glm::vec3*}             bbMax
 */
void MathHelp::getAABB( vector<cl_float4> vertices, glm::vec3* bbMin, glm::vec3* bbMax ) {
	*bbMin = glm::vec3( vertices[0].x, vertices[0].y, vertices[0].z );
	*bbMax = glm::vec3( vertices[0].x, vertices[0].y, vertices[0].z );

	for( cl_uint i = 1; i < vertices.size(); i++ ) {
		cl_float4 v = vertices[i];

		(*bbMin)[0] = ( (*bbMin)[0] < v.x ) ? (*bbMin)[0] : v.x;
		(*bbMin)[1] = ( (*bbMin)[1] < v.y ) ? (*bbMin)[1] : v.y;
		(*bbMin)[2] = ( (*bbMin)[2] < v.z ) ? (*bbMin)[2] : v.z;

		(*bbMax)[0] = ( (*bbMax)[0] > v.x ) ? (*bbMax)[0] : v.x;
		(*bbMax)[1] = ( (*bbMax)[1] > v.y ) ? (*bbMax)[1] : v.y;
		(*bbMax)[2] = ( (*bbMax)[2] > v.z ) ? (*bbMax)[2] : v.z;
	}
}


/**
 * Calculate the bounding box from the given list of bounding boxes.
 * @param {std::vector<glm::vec3>} bbMins
 * @param {std::vector<glm::vec3>} bbMaxs
 * @param {glm::vec3*}             bbMin
 * @param {glm::vec3*}             bbMax
 */
void MathHelp::getAABB(
	vector<glm::vec3> bbMins, vector<glm::vec3> bbMaxs, glm::vec3* bbMin, glm::vec3* bbMax
) {
	(*bbMin)[0] = bbMins[0][0];
	(*bbMin)[1] = bbMins[0][1];
	(*bbMin)[2] = bbMins[0][2];

	(*bbMax)[0] = bbMaxs[0][0];
	(*bbMax)[1] = bbMaxs[0][1];
	(*bbMax)[2] = bbMaxs[0][2];

	for( cl_uint i = 1; i < bbMins.size(); i++ ) {
		(*bbMin)[0] = glm::min( bbMins[i][0], (*bbMin)[0] );
		(*bbMin)[1] = glm::min( bbMins[i][1], (*bbMin)[1] );
		(*bbMin)[2] = glm::min( bbMins[i][2], (*bbMin)[2] );

		(*bbMax)[0] = glm::max( bbMaxs[i][0], (*bbMax)[0] );
		(*bbMax)[1] = glm::max( bbMaxs[i][1], (*bbMax)[1] );
		(*bbMax)[2] = glm::max( bbMaxs[i][2], (*bbMax)[2] );
	}
}


/**
 * Get the surface are of a bounding box.
 * @param  {glm::vec3} bbMin
 * @param  {glm::vec3} bbMax
 * @return {cl_float}        Surface area.
 */
cl_float MathHelp::getSurfaceArea( glm::vec3 bbMin, glm::vec3 bbMax ) {
	cl_float xy = 2.0f * ( bbMax[0] - bbMin[0] ) * ( bbMax[1] - bbMin[1] );
	cl_float zy = 2.0f * ( bbMax[2] - bbMin[2] ) * ( bbMax[1] - bbMin[1] );
	cl_float xz = 2.0f * ( bbMax[0] - bbMin[0] ) * ( bbMax[2] - bbMin[2] );

	return xy + zy + xz;
}


/**
 * Get the bounding box a face (triangle).
 * @param {cl_uint4}               face
 * @param {std::vector<cl_float4>} vertices
 * @param {glm::vec3*}             bbMin
 * @param {glm::vec3*}             bbMax
 */
void MathHelp::getTriangleAABB( cl_float4 v0, cl_float4 v1, cl_float4 v2, glm::vec3* bbMin, glm::vec3* bbMax ) {
	vector<cl_float4> vertices;

	vertices.push_back( v0 );
	vertices.push_back( v1 );
	vertices.push_back( v2 );

	MathHelp::getAABB( vertices, bbMin, bbMax );
}


/**
 * Get the center point of the bounding box of a triangle.
 * @param  {cl_float4} v0 Vertex of the triangle.
 * @param  {cl_float4} v1 Vertex of the triangle.
 * @param  {cl_float4} v2 Vertex of the triangle.
 * @return {glm::vec3}    Center point.
 */
glm::vec3 MathHelp::getTriangleCenter( cl_float4 v0, cl_float4 v1, cl_float4 v2 ) {
	glm::vec3 bbMin;
	glm::vec3 bbMax;
	MathHelp::getTriangleAABB( v0, v1, v2, &bbMin, &bbMax );

	return ( bbMax - bbMin ) / 2.0f;
}


/**
 * Get the centroid of a triangle.
 * @param  {cl_float4} v0 Vertex of the triangle.
 * @param  {cl_float4} v1 Vertex of the triangle.
 * @param  {cl_float4} v2 Vertex of the triangle.
 * @return {glm::vec3}    Centroid.
 */
glm::vec3 MathHelp::getTriangleCentroid( cl_float4 v0, cl_float4 v1, cl_float4 v2 ) {
	glm::vec3 a( v0.x, v0.y, v0.z );
	glm::vec3 b( v1.x, v1.y, v1.z );
	glm::vec3 c( v2.x, v2.y, v2.z );

	return ( a + b + c ) / 3.0f;
}


/**
 * Find the intersection of a line with a plane (3D).
 * @param  {glm::vec3} p          A point p on the line.
 * @param  {glm::vec3} q          A point q on the line.
 * @param  {glm::vec3} x          A point x on the plane.
 * @param  {glm::vec3} nl         Normal of the plane.
 * @param  {bool*}     isParallel Flag, that will be set to signalise if the line is parallel to the plane (= no intersection).
 * @return {glm::vec3}            The point of intersection.
 */
glm::vec3 MathHelp::intersectLinePlane( glm::vec3 p, glm::vec3 q, glm::vec3 x, glm::vec3 nl, bool* isParallel ) {
	glm::vec3 hit;
	glm::vec3 u = q - p;
	glm::vec3 w = p - x;
	cl_float d = glm::dot( nl, u );

	if( glm::abs( d ) < 0.000001f ) {
		*isParallel = true;
	}
	else {
		cl_float t = -glm::dot( nl, w ) / d;
		hit = p + u * t;
		*isParallel = false;
	}

	return hit;
}


glm::vec3 MathHelp::projectOnPlane( glm::vec3 q, glm::vec3 p, glm::vec3 n ) {
	return q - glm::dot( q - p, n ) * n;
}


/**
 * Convert an angle from radians to degree.
 * @param  {cl_float} rad Angle in radians.
 * @return {cl_float}     Angle in degree.
 */
cl_float MathHelp::radToDeg( cl_float rad ) {
	return ( rad * 180.0f / MH_PI );
}
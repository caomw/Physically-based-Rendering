#ifndef PATH_TRACER_H
#define PATH_TRACER_H

#include <algorithm>
#include <boost/date_time/posix_time/posix_time.hpp>
#include <ctime>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/matrix_inverse.hpp>
#include <string>
#include <vector>

#include "Camera.h"
#include "CL.h"
#include "Cfg.h"
#include "KdTree.h"
#include "MtlParser.h"

using std::vector;


class Camera;


class PathTracer {

	public:
		PathTracer();
		~PathTracer();
		vector<cl_float> generateImage();
		CL* getCLObject();
		void initOpenCLBuffers(
			vector<cl_float> vertices, vector<cl_uint> faces, vector<cl_float> normals,
			vector<cl_uint> facesVN, vector<cl_int> facesMtl, vector<material_t> materials,
			vector<light_t> lights,
			vector<kdNode_t> kdNodes, cl_uint rootIndex
		);
		void resetSampleCount();
		void setCamera( Camera* camera );
		void setFOV( cl_float fov );
		void setWidthAndHeight( cl_uint width, cl_uint height );
		void updateLights( vector<light_t> lights );

	protected:
		void clInitRays( cl_float timeSinceStart );
		void clPathTracing( cl_float timeSinceStart );
		void clSetColors( cl_float timeSinceStart );
		void clShadowTest( cl_float timeSinceStart );
		glm::vec3 getJitter();
		cl_float getTimeSinceStart();
		void initArgsKernelPathTracing();
		void initArgsKernelRays();
		void initArgsKernelSetColors();
		void initArgsKernelShadowTest();
		void initKernelArgs();
		void kdNodesToVectors(
			vector<kdNode_t> kdNodes,
			vector<cl_float>* kdSplits, vector<cl_float>* kdBB,
			vector<cl_int>* kdMeta, vector<cl_float>* kdFaces,
			vector<cl_int>* kdRopes, vector<cl_uint> faces, vector<cl_float> vertices
		);
		void updateEyeBuffer();

	private:
		cl_uint mBounces;
		cl_uint mHeight;
		cl_uint mWidth;
		cl_float mFOV;

		cl_int mKdRootNodeIndex;
		cl_uint mSampleCount;

		vector<cl_float> mTextureOut;

		cl_kernel mKernelPathTracing;
		cl_kernel mKernelRays;
		cl_kernel mKernelSetColors;
		cl_kernel mKernelShadowTest;

		cl_mem mBufScNormals;
		cl_mem mBufScFacesVN;

		cl_mem mBufKdNodes;
		cl_mem mBufKdNodeSplits;
		cl_mem mBufKdNodeBB;
		cl_mem mBufKdNodeMeta;
		cl_mem mBufKdNodeFaces;
		cl_mem mBufKdNodeRopes;

		cl_mem mBufMaterialsColorDiffuse;
		cl_mem mBufMaterialToFace;

		cl_mem mBufEye;
		cl_mem mBufHitNormals;
		cl_mem mBufHits;
		cl_mem mBufLights;
		cl_mem mBufNormals;
		cl_mem mBufOrigins;
		cl_mem mBufRays;
		cl_mem mBufTextureIn;
		cl_mem mBufTextureOut;

		Camera* mCamera;
		CL* mCL;
		boost::posix_time::ptime mTimeSinceStart;

};

#endif

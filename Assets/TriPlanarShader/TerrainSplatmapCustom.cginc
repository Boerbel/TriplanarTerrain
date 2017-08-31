// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef TERRAIN_SPLATMAP_COMMON_CGINC_INCLUDED
#define TERRAIN_SPLATMAP_COMMON_CGINC_INCLUDED

struct Input
{
	float3 worldPos;
	float3 worldNormal;
    float2 uv_Splat0 : TEXCOORD0;
    float2 uv_Splat1 : TEXCOORD1;
    float2 uv_Splat2 : TEXCOORD2;
    float2 uv_Splat3 : TEXCOORD3;
    float2 tc_Control : TEXCOORD4;  // Not prefixing '_Contorl' with 'uv' allows a tighter packing of interpolators, which is necessary to support directional lightmap.
    UNITY_FOG_COORDS(5)
};

sampler2D _Control;
float4 _Control_ST;
sampler2D _Splat0,_Splat1,_Splat2,_Splat3;

#ifdef _TERRAIN_NORMAL_MAP
    sampler2D _Normal0, _Normal1, _Normal2, _Normal3;
#endif

void SplatmapVert(inout appdata_full v, out Input data)
{
    UNITY_INITIALIZE_OUTPUT(Input, data);
    data.tc_Control = TRANSFORM_TEX(v.texcoord, _Control);  // Need to manually transform uv here, as we choose not to use 'uv' prefix for this texcoord.
    float4 pos = UnityObjectToClipPos(v.vertex);
    UNITY_TRANSFER_FOG(data, pos);

#ifdef _TERRAIN_NORMAL_MAP
    v.tangent.xyz = cross(v.normal, float3(0,0,1));
    v.tangent.w = -1;
#endif
}

#ifdef TERRAIN_STANDARD_SHADER
void SplatmapMix(Input IN, half4 defaultAlpha, out half4 splat_control, out half weight, out fixed4 mixedDiffuse, inout fixed3 mixedNormal)
#else
void SplatmapMix(Input IN, out half4 splat_control, out half weight, out fixed4 mixedDiffuse, inout fixed3 mixedNormal)
#endif
{
    splat_control = tex2D(_Control, IN.tc_Control);
    weight = dot(splat_control, half4(1,1,1,1));

    #if !defined(SHADER_API_MOBILE) && defined(TERRAIN_SPLAT_ADDPASS)
        clip(weight == 0.0f ? -1 : 1);
    #endif

    // Normalize weights before lighting and restore weights in final modifier functions so that the overal
    // lighting result can be correctly weighted.
    splat_control /= (weight + 1e-3f);


	float3 blending = abs( IN.worldNormal );
	blending = normalize(max(blending, 0.00001)); // Force weights to sum to 1.0
	float b = (blending.x + blending.y + blending.z);
	blending /= float3(b, b, b);

	//Splat0
	float4 xaxis0 = tex2D(_Splat0, IN.worldPos.yz/4);
	float4 yaxis0 = tex2D(_Splat0, IN.worldPos.xz/4);
	float4 zaxis0 = tex2D(_Splat0, IN.worldPos.xy/4);

	float4 splat0Tex = xaxis0 * blending.x + yaxis0 * blending.y + zaxis0 * blending.z;

	//Splat1
	float4 xaxis1 = tex2D(_Splat1, IN.worldPos.yz/4);
	float4 yaxis1 = tex2D(_Splat1, IN.worldPos.xz/4);
	float4 zaxis1 = tex2D(_Splat1, IN.worldPos.xy/4);

	float4 splat1Tex = xaxis1 * blending.x + yaxis1 * blending.y + zaxis1 * blending.z;

	//Splat2
	float4 xaxis2 = tex2D(_Splat2, IN.worldPos.yz/4);
	float4 yaxis2 = tex2D(_Splat2, IN.worldPos.xz/4);
	float4 zaxis2 = tex2D(_Splat2, IN.worldPos.xy/4);

	float4 splat2Tex = xaxis2 * blending.x + yaxis2 * blending.y + zaxis2 * blending.z;

	//Splat3
	float4 xaxis3 = tex2D(_Splat3, IN.worldPos.yz/4);
	float4 yaxis3 = tex2D(_Splat3, IN.worldPos.xz/4);
	float4 zaxis3 = tex2D(_Splat3, IN.worldPos.xy/4);

	float4 splat3Tex = xaxis3 * blending.x + yaxis3 * blending.y + zaxis3 * blending.z;



    mixedDiffuse = 0.0f;
    #ifdef TERRAIN_STANDARD_SHADER
        mixedDiffuse += splat_control.r * splat0Tex * half4(1.0, 1.0, 1.0, defaultAlpha.r);
        mixedDiffuse += splat_control.g * splat1Tex * half4(1.0, 1.0, 1.0, defaultAlpha.g);
        mixedDiffuse += splat_control.b * splat2Tex * half4(1.0, 1.0, 1.0, defaultAlpha.b);
        mixedDiffuse += splat_control.a * splat3Tex * half4(1.0, 1.0, 1.0, defaultAlpha.a);
    #else
        mixedDiffuse += splat_control.r * splat0Tex;
        mixedDiffuse += splat_control.g * splat1Tex;
        mixedDiffuse += splat_control.b * splat2Tex;
        mixedDiffuse += splat_control.a * splat3Tex;
    #endif

    #ifdef _TERRAIN_NORMAL_MAP
        fixed4 nrm = 0.0f;
        nrm += splat_control.r * tex2D(_Normal0, IN.worldPos);
        nrm += splat_control.g * tex2D(_Normal1, IN.worldPos);
        nrm += splat_control.b * tex2D(_Normal2, IN.worldPos);
        nrm += splat_control.a * tex2D(_Normal3, IN.worldPos);
        mixedNormal = UnpackNormal(nrm);
    #endif
}

#ifndef TERRAIN_SURFACE_OUTPUT
    #define TERRAIN_SURFACE_OUTPUT SurfaceOutput
#endif

void SplatmapFinalColor(Input IN, TERRAIN_SURFACE_OUTPUT o, inout fixed4 color)
{
    color *= o.Alpha;
    #ifdef TERRAIN_SPLAT_ADDPASS
        UNITY_APPLY_FOG_COLOR(IN.fogCoord, color, fixed4(0,0,0,0));
    #else
        UNITY_APPLY_FOG(IN.fogCoord, color);
    #endif
}

void SplatmapFinalPrepass(Input IN, TERRAIN_SURFACE_OUTPUT o, inout fixed4 normalSpec)
{
    normalSpec *= o.Alpha;
}

void SplatmapFinalGBuffer(Input IN, TERRAIN_SURFACE_OUTPUT o, inout half4 outGBuffer0, inout half4 outGBuffer1, inout half4 outGBuffer2, inout half4 emission)
{
    UnityStandardDataApplyWeightToGbuffer(outGBuffer0, outGBuffer1, outGBuffer2, o.Alpha);
    emission *= o.Alpha;
}

#endif // TERRAIN_SPLATMAP_COMMON_CGINC_INCLUDED

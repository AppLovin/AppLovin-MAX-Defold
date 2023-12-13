#if defined(DM_PLATFORM_ANDROID)

#include <jni.h>
/* Header for class com_defold_applovin_MaxDefoldPlugin */

#ifndef COM_DEFOLD_APPLOVIN_MaxDefoldPlugin_H
#define COM_DEFOLD_APPLOVIN_MaxDefoldPlugin_H
#ifdef __cplusplus
extern "C" {
#endif
    /*
    * Class:     com_defold_applovin_MaxDefoldPlugin
    * Method:    appLovinAddToQueue_first_arg
    * Signature: (ILjava/lang/String;I)V
    */
    JNIEXPORT void JNICALL Java_com_defold_applovin_MaxDefoldPlugin_appLovinAddToQueue
        (JNIEnv *, jclass, jstring, jstring);

#ifdef __cplusplus
}
#endif
#endif

#endif

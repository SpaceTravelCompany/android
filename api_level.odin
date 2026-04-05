package android

foreign import android "system:android"

@(default_calling_convention="c")
foreign android {
	/**
	 * Returns the API level of the Android platform version running on this device.
	 *
	 * Available since API level 29.
	 */
	android_get_device_api_level :: proc() -> i32 ---
}

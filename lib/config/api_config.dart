class ApiConfig {

  // ================= OLD LOCAL SETUP (KEEPING FOR FUTURE USE) =================
  // If running on an Android Emulator, use 10.0.2.2
  // If running on a physical device, use LAN IP (e.g. 192.168.1.6)

  static const String hostIp = "192.168.1.4"; // Change to "10.0.2.2" for emulator
  static const String port = "5000";
   static const String baseUrl = "http://$hostIp:$port";


  // ================= CURRENT WORKING SETUP (CLOUDFLARE TUNNEL) =================
  // Using tunnel to bypass network restrictions

  // static const String baseUrl = "https://known-michelle-webshots-harvard.trycloudflare.com";


// ================= OPTIONAL SWITCH (FUTURE USE) =================
// You can enable this later if you want to toggle easily

// static const bool useCloud = true;

// static const String local = "http://192.168.1.6:5000";
// static const String cloud = "https://above-dns-silicon-sleeping.trycloudflare.com";

// static String get baseUrl => useCloud ? cloud : local;

}

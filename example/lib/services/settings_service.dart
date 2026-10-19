import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RtlSource {
  nativeUsb, // Native USB RTL-SDR (built-in, no external app needed)
  hackrf, // Native USB HackRF (built-in, no external app needed)
  remote, // Connect to remote rtl_tcp server
}

class SettingsService extends ChangeNotifier {
  RtlSource _rtlSource = RtlSource.nativeUsb;
  String _remoteHost = '192.168.1.240';
  int _remotePort = 1234;
  double _frequency = 771.18125;
  bool _audioEnabled = true;
  int _gain = 48;
  int _ppm = 0;
  int _sampleRate = 1536000;  // 1.536 MSPS - matches DSD rtl_tcp default
  bool _biasTee = false; // Bias-T enable for RTL-SDR
  // P25 demodulation: 0 = Auto, 1 = CQPSK / LSM (simulcast), 2 = C4FM
  int _p25Modulation = 0;
  // Receive enhancements
  bool _autoPpm = true;        // spectrum-based PPM drift correction
  bool _fll = false;           // carrier frequency tracking (C4FM)
  bool _ted = false;           // symbol timing recovery (C4FM)
  bool _autoGain = false;      // automatic tuner gain (overrides manual gain)
  bool _bothSlots = true;      // play both TDMA slots (P25 Phase 2 / DMR)

  // Native USB state (RTL-SDR)
  int _nativeUsbFd = -1;
  String _nativeUsbPath = '';
  
  // HackRF specific settings
  int _hackrfLnaGain = 16; // LNA gain 0-40 dB (8 dB steps)
  int _hackrfVgaGain = 16; // VGA gain 0-62 dB (2 dB steps)
  int _hackrfBandwidth = 1750000; // Baseband filter bandwidth in Hz
  bool _hackrfAmpEnable = false; // RF amplifier enable

  SettingsService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final rtlSourceIndex = prefs.getInt('sdr_rtl_source');
    if (rtlSourceIndex != null && rtlSourceIndex < RtlSource.values.length) {
      _rtlSource = RtlSource.values[rtlSourceIndex];
    }
    
    _remoteHost = prefs.getString('sdr_remote_host') ?? _remoteHost;
    _remotePort = prefs.getInt('sdr_remote_port') ?? _remotePort;
    _gain = prefs.getInt('sdr_gain') ?? _gain;
    _ppm = prefs.getInt('sdr_ppm') ?? _ppm;
    _biasTee = prefs.getBool('sdr_bias_tee') ?? _biasTee;
    _p25Modulation = prefs.getInt('sdr_p25_modulation') ?? _p25Modulation;
    _autoPpm = prefs.getBool('sdr_auto_ppm') ?? _autoPpm;
    _fll = prefs.getBool('sdr_fll') ?? _fll;
    _ted = prefs.getBool('sdr_ted') ?? _ted;
    _autoGain = prefs.getBool('sdr_auto_gain') ?? _autoGain;
    _bothSlots = prefs.getBool('sdr_both_slots') ?? _bothSlots;
    _hackrfLnaGain = prefs.getInt('sdr_hackrf_lna_gain') ?? _hackrfLnaGain;
    _hackrfVgaGain = prefs.getInt('sdr_hackrf_vga_gain') ?? _hackrfVgaGain;
    
    notifyListeners();
    
    if (kDebugMode) {
      print('Loaded SDR settings from storage');
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sdr_rtl_source', _rtlSource.index);
    await prefs.setString('sdr_remote_host', _remoteHost);
    await prefs.setInt('sdr_remote_port', _remotePort);
    await prefs.setInt('sdr_gain', _gain);
    await prefs.setInt('sdr_ppm', _ppm);
    await prefs.setBool('sdr_bias_tee', _biasTee);
    await prefs.setInt('sdr_p25_modulation', _p25Modulation);
    await prefs.setBool('sdr_auto_ppm', _autoPpm);
    await prefs.setBool('sdr_fll', _fll);
    await prefs.setBool('sdr_ted', _ted);
    await prefs.setBool('sdr_auto_gain', _autoGain);
    await prefs.setBool('sdr_both_slots', _bothSlots);
    await prefs.setInt('sdr_hackrf_lna_gain', _hackrfLnaGain);
    await prefs.setInt('sdr_hackrf_vga_gain', _hackrfVgaGain);
    
    if (kDebugMode) {
      print('Saved SDR settings to storage');
    }
  }

  RtlSource get rtlSource => _rtlSource;
  String get remoteHost => _remoteHost;
  int get remotePort => _remotePort;
  double get frequency => _frequency;
  bool get audioEnabled => _audioEnabled;
  int get gain => _gain;
  int get ppm => _ppm;
  int get sampleRate => _sampleRate;
  bool get biasTee => _biasTee;
  int get p25Modulation => _p25Modulation;
  bool get autoPpm => _autoPpm;
  bool get fll => _fll;
  bool get ted => _ted;
  bool get autoGain => _autoGain;
  bool get bothSlots => _bothSlots;

  /// Tuner gain to send to the decoder, in tenths of a dB (0 = automatic).
  /// The decoder expects tenths of a dB for both USB and rtl_tcp sources.
  int get tunerGainTenthsDb => _autoGain ? 0 : _gain * 10;
  int get nativeUsbFd => _nativeUsbFd;
  String get nativeUsbPath => _nativeUsbPath;
  bool get hasNativeUsbDevice => _nativeUsbFd >= 0;
  
  // HackRF getters
  int get hackrfLnaGain => _hackrfLnaGain;
  int get hackrfVgaGain => _hackrfVgaGain;
  int get hackrfBandwidth => _hackrfBandwidth;
  bool get hackrfAmpEnable => _hackrfAmpEnable;
  
  int get frequencyHz => (_frequency * 1000000).round();
  
  // Get effective host/port based on source (for remote mode)
  String get effectiveHost => _remoteHost;
  int get effectivePort => _remotePort;

  void setRtlSource(RtlSource value) {
    _rtlSource = value;
    _saveSettings();
    notifyListeners();
  }

  void updateRemoteHost(String value) {
    _remoteHost = value;
    _saveSettings();
    notifyListeners();
  }

  void updateRemotePort(int value) {
    _remotePort = value;
    _saveSettings();
    notifyListeners();
  }

  void updateFrequency(double value) {
    _frequency = value;
    notifyListeners();
  }

  void setAudioEnabled(bool value) {
    _audioEnabled = value;
    notifyListeners();
  }

  void updateGain(int value) {
    _gain = value;
    _saveSettings();
    notifyListeners();
  }

  void updatePpm(int value) {
    _ppm = value;
    _saveSettings();
    notifyListeners();
  }

  void updateBiasTee(bool value) {
    _biasTee = value;
    _saveSettings();
    notifyListeners();
  }

  void updateP25Modulation(int value) {
    _p25Modulation = (value >= 0 && value <= 2) ? value : 0;
    _saveSettings();
    notifyListeners();
  }

  void updateReceiveOptions({
    bool? autoPpm,
    bool? fll,
    bool? ted,
    bool? autoGain,
    bool? bothSlots,
  }) {
    if (autoPpm != null) _autoPpm = autoPpm;
    if (fll != null) _fll = fll;
    if (ted != null) _ted = ted;
    if (autoGain != null) _autoGain = autoGain;
    if (bothSlots != null) _bothSlots = bothSlots;
    _saveSettings();
    notifyListeners();
  }

  void updateSampleRate(int value) {
    _sampleRate = value;
    notifyListeners();
  }
  
  void setNativeUsbDevice(int fd, String path) {
    _nativeUsbFd = fd;
    _nativeUsbPath = path;
    notifyListeners();
  }
  
  void clearNativeUsbDevice() {
    _nativeUsbFd = -1;
    _nativeUsbPath = '';
    notifyListeners();
  }
  
  // HackRF setters
  void updateHackrfLnaGain(int value) {
    _hackrfLnaGain = value;
    _saveSettings();
    notifyListeners();
  }
  
  void updateHackrfVgaGain(int value) {
    _hackrfVgaGain = value;
    _saveSettings();
    notifyListeners();
  }
  
  void updateHackrfBandwidth(int value) {
    _hackrfBandwidth = value;
    notifyListeners();
  }
  
  void setHackrfAmpEnable(bool value) {
    _hackrfAmpEnable = value;
    notifyListeners();
  }
}

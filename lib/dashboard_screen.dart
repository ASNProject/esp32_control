// Copyright 2024 ariefsetyonugroho
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  BluetoothDevice? _selectedDevice;
  BluetoothConnection? _connection;
  bool isConnected = false;
  String receivedData = '';
  List<BluetoothDevice> _devices = [];
  late MapController _mapController;
  bool _mapReady = false;

  // Data
  String? latitude;
  String? longitude;
  String? temperature;
  String? humidity;
  String? anemometer;
  String? winddirection;
  String? bottomdistance;
  String? frontdistance;
  String? speed;
  String? radarangle;
  String? warning;
  String? status;
  String? startboard;
  String? port;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Meminta izin yang diperlukan
    if (await Permission.bluetooth.isDenied ||
        await Permission.bluetoothScan.isDenied ||
        await Permission.bluetoothConnect.isDenied ||
        await Permission.location.isDenied) {
      await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    }

    // Jika izin sudah diberikan, mulai pencarian perangkat Bluetooth
    if (await Permission.bluetoothConnect.isGranted) {
      _discoverDevices();
    }
  }

  Future<void> _discoverDevices() async {
    // Menemukan perangkat yang dipasangkan
    List<BluetoothDevice> devices =
        await FlutterBluetoothSerial.instance.getBondedDevices();

    setState(() {
      _devices = devices; // Menyimpan perangkat yang ditemukan
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      BluetoothConnection connection =
          await BluetoothConnection.toAddress(device.address);
      setState(() {
        _connection = connection;
        isConnected = true;
        _selectedDevice = device;
      });

      _connection!.input!.listen((data) {
        setState(() {
          receivedData = String.fromCharCodes(data);
          List<String> dataList = receivedData.split(',');
          if (dataList.length >= 14) {
            // Pastikan dataList memiliki setidaknya 14 elemen
            latitude = dataList[0];
            longitude = dataList[1];
            temperature = dataList[2];
            humidity = dataList[3];
            anemometer = dataList[4];
            winddirection = dataList[5];
            bottomdistance = dataList[6];
            frontdistance = dataList[7];
            speed = dataList[8];
            radarangle = dataList[9];
            warning = dataList[10];
            status = dataList[11];
            startboard = dataList[12];
            port = dataList[13];
          }
        });
      });
    } catch (e) {}
  }

  Future<void> _disconnectFromDevice() async {
    if (_connection != null) {
      await _connection!.close();
      setState(() {
        _connection = null;
        isConnected = false;
        _selectedDevice = null;
        receivedData = '';
      });
    }
  }

  // Fungsi untuk mengirim data ke perangkat Bluetooth
  Future<void> _sendData(String data) async {
    if (_connection != null && isConnected) {
      _connection!.output.add(Uint8List.fromList(data.codeUnits));
      await _connection!.output.allSent;
      print('Data sent: $data');
    } else {
      print('No connection available');
    }
  }

  @override
  void dispose() {
    _disconnectFromDevice(); // Memutuskan koneksi saat widget dihapus
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ESP32 Control',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select a Bluetooth Device to Connect:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.black12,
                          ),
                          borderRadius: BorderRadius.circular(8)),
                      child: DropdownButton<BluetoothDevice>(
                        underline: const SizedBox.shrink(),
                        value: _selectedDevice,
                        hint: const Text('Select a device'),
                        isExpanded: true,
                        items: _devices.map((BluetoothDevice device) {
                          return DropdownMenuItem<BluetoothDevice>(
                            value: device,
                            child: Text(device.name ?? 'Unknown Device'),
                          );
                        }).toList(),
                        onChanged: (BluetoothDevice? newValue) {
                          if (newValue != null) {
                            _connectToDevice(newValue);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8.0,
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10), // Radius sudut tombol
                      ),
                    ),
                    onPressed:
                        isConnected ? _disconnectFromDevice : _discoverDevices,
                    child: Icon(
                      (isConnected ? Icons.stop : Icons.refresh),
                      color: isConnected ? Colors.red : Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 8,
              ),
              isConnected
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (latitude != null && longitude != null) _buildMap(),
                        const SizedBox(
                          height: 10,
                        ),
                        _buildRowWidget(
                          'Latitude',
                          latitude ?? '0',
                          'Longitude',
                          longitude ?? '0',
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        _buildRowWidget(
                          'Temperature (°C)',
                          temperature ?? '0',
                          'Humidity (%)',
                          humidity ?? '0',
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        _buildRowWidget(
                          'Anemometer (m/s)',
                          anemometer ?? '0',
                          'Wind Direction',
                          winddirection ?? '-',
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        _buildRowWidget(
                          'Bottom Distance (cm)',
                          bottomdistance ?? '0',
                          'Front Distance (cm)',
                          frontdistance ?? '0',
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        _buildRowWidget(
                          'Speed (km/h)',
                          speed ?? '0',
                          'Radar Angle',
                          radarangle ?? '0',
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.lightBlueAccent,
                            border: Border.all(
                              color: Colors.black12,
                            ),
                            borderRadius: BorderRadius.circular(
                              8.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Warning',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                warning ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.lightBlueAccent,
                            border: Border.all(
                              color: Colors.black12,
                            ),
                            borderRadius: BorderRadius.circular(
                              8.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                status ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        _buildButton(),
                      ],
                    )
                  : SizedBox(
                      height: MediaQuery.of(context).size.height * .5,
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bluetooth_disabled,
                            size: 50,
                          ),
                          Center(
                            child: Text(
                                'Silahkan hubungkan Bluetooth terlebih dahulu!'),
                          )
                        ],
                      ),
                    )
            ],
          ),
        ),
      ),
    );
  }

  void _updateMap() {
    if (latitude != null && longitude != null && _mapReady) {
      _mapController.move(
        LatLng(double.parse(latitude!), double.parse(longitude!)),
        16,
      );
    }
  }

  Widget _buildMap() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * .5,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter:
              LatLng(double.parse(latitude!), double.parse(longitude!)),
          initialZoom: 16.0,
          onMapReady: () {
            setState(() {
              _mapReady = true;
            });
            _updateMap();
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.esp32_control',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point:
                    LatLng(double.parse(latitude!), double.parse(longitude!)),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  _buildRowWidget(
    String titleLeft,
    String valueLeft,
    String titleRight,
    String valueRight,
  ) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.yellowAccent,
              border: Border.all(
                color: Colors.black12,
              ),
              borderRadius: BorderRadius.circular(
                8.0,
              ),
            ),
            child: Column(
              children: [
                Text(
                  titleLeft,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  valueLeft,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.yellowAccent,
              border: Border.all(
                color: Colors.black12,
              ),
              borderRadius: BorderRadius.circular(
                8.0,
              ),
            ),
            child: Column(
              children: [
                Text(
                  titleRight,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  valueRight,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  _buildButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildIndicator(
              'STANDBOARD',
              startboard ?? '0',
            ),
            _buildIndicator(
              'PORT',
              port ?? '0',
            ),
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () {
                      _sendData('#a');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.amber, // Ganti dengan warna yang diinginkan
                    ),
                    child: const Text(
                      'STARTBOARD',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () {
                      _sendData('#b');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.amber, // Ganti dengan warna yang diinginkan
                    ),
                    child: const Text(
                      'PORT',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(
          height: 4,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () {
                      _sendData('#c');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.amber, // Ganti dengan warna yang diinginkan
                    ),
                    child: const Text(
                      'FORWARD1',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () {
                      _sendData('#d');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.amber, // Ganti dengan warna yang diinginkan
                    ),
                    child: const Text(
                      'FORWARD2',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () {
                      _sendData('#e');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.amber, // Ganti dengan warna yang diinginkan
                    ),
                    child: const Text(
                      'FORWARD3',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(
          height: 4,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () {
                      _sendData('#f');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.amber, // Ganti dengan warna yang diinginkan
                    ),
                    child: const Text(
                      'STOP',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () {
                      _sendData('#g');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.amber, // Ganti dengan warna yang diinginkan
                    ),
                    child: const Text(
                      'BACK1',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () {
                      _sendData('#h');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.amber, // Ganti dengan warna yang diinginkan
                    ),
                    child: const Text(
                      'BACK2',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(
          height: 4,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () {
                      _sendData('#i');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.amber, // Ganti dengan warna yang diinginkan
                    ),
                    child: const Text(
                      'BACK3',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () {
                      _sendData('#j');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.amber, // Ganti dengan warna yang diinginkan
                    ),
                    child: const Text(
                      '5°',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () {
                      _sendData('#k');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.amber, // Ganti dengan warna yang diinginkan
                    ),
                    child: const Text(
                      '15°',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(
          height: 4,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () {
                      _sendData('#l');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.amber, // Ganti dengan warna yang diinginkan
                    ),
                    child: const Text(
                      '25°',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () {
                      _sendData('#m');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.amber, // Ganti dengan warna yang diinginkan
                    ),
                    child: const Text(
                      '35°',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () {
                      _sendData('#n');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.amber, // Ganti dengan warna yang diinginkan
                    ),
                    child: const Text(
                      '45°',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  _buildIndicator(
    String title,
    String value,
  ) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value == '1' ? Colors.green : Colors.red,
          ),
        )
      ],
    );
  }
}

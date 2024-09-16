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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:logger/logger.dart';
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
  String? compass;
  String? axisx;
  String? axisy;
  String? status;
  String? run;
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
          if (dataList.length >= 16) {
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
            compass = dataList[9];
            axisx = dataList[10];
            axisy = dataList[11];
            status = dataList[12];
            run = dataList[13];
            startboard = dataList[14];
            port = dataList[15];
            Logger().i(receivedData);
          }
        });
      });
    } catch (e) {
      Logger().e(e.toString());
    }
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

  Timer? _timer;
  bool _isSending = false;

  // Fungsi untuk mengirim data ke perangkat Bluetooth
  Future<void> _sendData(String data) async {
    if (_connection != null && isConnected) {
      _connection!.output.add(Uint8List.fromList(data.codeUnits));
      await _connection!.output.allSent;
      Logger().i('Data sent: $data');
    } else {
      Logger().i('No connection available');
    }
  }

  void _startSendingData(String data) {
    if (!_isSending) {
      _isSending = true;
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (_isSending) {
          _sendData(data); // Kirim data huruf besar secara terus-menerus
        }
      });
    }
  }

  void _stopSendingData(String data) {
    if (_isSending) {
      _isSending = false;
      _timer?.cancel();
      _sendData(data.toLowerCase());
    }
  }

  @override
  void dispose() {
    _disconnectFromDevice();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BOAT CONTROL',
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
                          'Compass',
                          compass ?? '0',
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        _buildRowWidget(
                          'Axis X',
                          axisx ?? '0',
                          'Axis Y',
                          axisy ?? '0',
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.red,
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
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                status ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
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
                                'Run',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                run ?? '-',
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: GestureDetector(
                    onTapDown: (_) {
                      _startSendingData('A');
                    },
                    onTapUp: (_) {
                      _stopSendingData(
                          'a'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    onTapCancel: () {
                      _stopSendingData(
                          'a'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    child: ElevatedButton(
                      onPressed: () {
                        // _sendData('a');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.amber, // Ganti dengan warna yang diinginkan
                      ),
                      child: const Text(
                        'ANCHOR L',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _buildIndicator(
              'STARBOARD',
              startboard ?? '0',
              Colors.red,
            ),
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: GestureDetector(
                    onTapDown: (_) {
                      _startSendingData('B');
                    },
                    onTapUp: (_) {
                      _stopSendingData(
                          'b'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    onTapCancel: () {
                      _stopSendingData(
                          'b'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    child: ElevatedButton(
                      onPressed: () {
                        // _sendData('a');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.amber, // Ganti dengan warna yang diinginkan
                      ),
                      child: const Text(
                        'STARBOARD',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                        ),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: GestureDetector(
                    onTapDown: (_) {
                      _startSendingData('C');
                    },
                    onTapUp: (_) {
                      _stopSendingData(
                          'c'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    onTapCancel: () {
                      _stopSendingData(
                          'c'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    child: ElevatedButton(
                      onPressed: () {
                        // _sendData('a');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.amber, // Ganti dengan warna yang diinginkan
                      ),
                      child: const Text(
                        'ANCHOR R',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _buildIndicator(
              'PORT',
              port ?? '0',
              Colors.green,
            ),
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: GestureDetector(
                    onTapDown: (_) {
                      _startSendingData('D');
                    },
                    onTapUp: (_) {
                      _stopSendingData(
                          'd'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    onTapCancel: () {
                      _stopSendingData(
                          'd'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    child: ElevatedButton(
                      onPressed: () {
                        // _sendData('a');
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
                ),
              ],
            ),
          ],
        ),
        const SizedBox(
          height: 4,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: GestureDetector(
                    onTapDown: (_) {
                      _startSendingData('E');
                    },
                    onTapUp: (_) {
                      _stopSendingData(
                          'e'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    onTapCancel: () {
                      _stopSendingData(
                          'e'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    child: ElevatedButton(
                      onPressed: () {},
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
                  child: GestureDetector(
                    onTapDown: (_) {
                      _startSendingData('F');
                    },
                    onTapUp: (_) {
                      _stopSendingData(
                          'f'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    onTapCancel: () {
                      _stopSendingData(
                          'f'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.amber, // Ganti dengan warna yang diinginkan
                      ),
                      child: const Text(
                        'FORWARD 1',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                        ),
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
                  child: GestureDetector(
                    onTapDown: (_) {
                      _startSendingData('G');
                    },
                    onTapUp: (_) {
                      _stopSendingData(
                          'g'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    onTapCancel: () {
                      _stopSendingData(
                          'g'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.amber, // Ganti dengan warna yang diinginkan
                      ),
                      child: const Text(
                        'BACK 1',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                        ),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: GestureDetector(
                    onTapDown: (_) {
                      _startSendingData('H');
                    },
                    onTapUp: (_) {
                      _stopSendingData(
                          'h'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    onTapCancel: () {
                      _stopSendingData(
                          'h'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.amber, // Ganti dengan warna yang diinginkan
                      ),
                      child: const Text(
                        '5',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                        ),
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
                  child: GestureDetector(
                    onTapDown: (_) {
                      _startSendingData('I');
                    },
                    onTapUp: (_) {
                      _stopSendingData(
                          'i'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    onTapCancel: () {
                      _stopSendingData(
                          'i'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.amber, // Ganti dengan warna yang diinginkan
                      ),
                      child: const Text(
                        'FORWARD 2',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                        ),
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
                  child: GestureDetector(
                    onTapDown: (_) {
                      _startSendingData('J');
                    },
                    onTapUp: (_) {
                      _stopSendingData(
                          'j'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    onTapCancel: () {
                      _stopSendingData(
                          'j'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.amber, // Ganti dengan warna yang diinginkan
                      ),
                      child: const Text(
                        'BACK 2',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                        ),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: GestureDetector(
                    onTapDown: (_) {
                      _startSendingData('K');
                    },
                    onTapUp: (_) {
                      _stopSendingData(
                          'k'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    onTapCancel: () {
                      _stopSendingData(
                          'k'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    child: ElevatedButton(
                      onPressed: () {},
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
                  child: GestureDetector(
                    onTapDown: (_) {
                      _startSendingData('L');
                    },
                    onTapUp: (_) {
                      _stopSendingData(
                          'l'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    onTapCancel: () {
                      _stopSendingData(
                          'l'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.amber, // Ganti dengan warna yang diinginkan
                      ),
                      child: const Text(
                        'FORWARD 3',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                        ),
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
                  child: GestureDetector(
                    onTapDown: (_) {
                      _startSendingData('M');
                    },
                    onTapUp: (_) {
                      _stopSendingData(
                          'm'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    onTapCancel: () {
                      _stopSendingData(
                          'm'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.amber, // Ganti dengan warna yang diinginkan
                      ),
                      child: const Text(
                        'BACK 3',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                        ),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 100,
                  child: GestureDetector(
                    onTapDown: (_) {
                      _startSendingData('N');
                    },
                    onTapUp: (_) {
                      _stopSendingData(
                          'n'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    onTapCancel: () {
                      _stopSendingData(
                          'n'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    child: ElevatedButton(
                      onPressed: () {},
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
                  child: GestureDetector(
                    onTapDown: (_) {
                      _startSendingData('O');
                    },
                    onTapUp: (_) {
                      _stopSendingData(
                          'o'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    onTapCancel: () {
                      _stopSendingData(
                          'o'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    child: ElevatedButton(
                      onPressed: () {},
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
                  child: GestureDetector(
                    onTapDown: (_) {
                      _startSendingData('P');
                    },
                    onTapUp: (_) {
                      _stopSendingData(
                          'p'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    onTapCancel: () {
                      _stopSendingData(
                          'p'); // Kirim huruf kecil ketika tombol dilepas
                    },
                    child: ElevatedButton(
                      onPressed: () {},
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
                ),
              ],
            ),
          ],
        ),
        const SizedBox(
          height: 4,
        ),
      ],
    );
  }

  _buildIndicator(
    String title,
    String value,
    Color color,
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
            border: Border.all(
              color: Colors.black12,
            ),
            shape: BoxShape.circle,
            color: value == '1' ? color : Colors.white,
          ),
        )
      ],
    );
  }
}

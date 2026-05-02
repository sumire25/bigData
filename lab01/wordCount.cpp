#include <iostream>
#include <vector>
#include <thread>
#include <string>
#include <unordered_map>
#include <cctype>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <algorithm>
#include <fstream>
#include <chrono>
using namespace std;

using WordMap = unordered_map<string, uint64_t>;

inline bool isWordChar(char c) {
    return isalpha(static_cast<unsigned char>(c));
}

void processChunk(const char* fileData, size_t startIdx, size_t endIdx, size_t fileSize, WordMap& localMap) {
    if (startIdx > 0 && isWordChar(fileData[startIdx - 1])) {
        while (startIdx < fileSize && isWordChar(fileData[startIdx])) {
            startIdx++;
        }
    }

    size_t i = startIdx;
    
    string currentWord;
    currentWord.reserve(128); 

    while (i < endIdx || (i < fileSize && isWordChar(fileData[i]))) {
        while (i < fileSize && !isWordChar(fileData[i])) {
            if (i >= endIdx) return; 
            i++;
        }

        if (i >= fileSize) break;

        size_t wordStart = i;
        
        while (i < fileSize && isWordChar(fileData[i])) {
            i++;
        }

        currentWord.clear();
        for (size_t k = wordStart; k < i; k++) {
            currentWord.push_back(tolower(static_cast<unsigned char>(fileData[k])));
        }

        localMap[currentWord]++;
    }
}

int main() {
    const char* filePath = "wikipedia.txt/wikipedia.txt";
    const char* outputPath = "wordCount.csv";
    const int numThreads = 4;

    auto startTime = chrono::high_resolution_clock::now();
    int fd = open(filePath, O_RDONLY);
    if (fd == -1) {
        cerr << "Could not open input file." << endl;
        return 1;
    }

    struct stat sb;
    if (fstat(fd, &sb) == -1) {
        cerr << "Could not retrieve file size." << endl;
        close(fd);
        return 1;
    }
    size_t fileSize = sb.st_size;

    const char* fileData = static_cast<const char*>(
        mmap(nullptr, fileSize, PROT_READ, MAP_PRIVATE, fd, 0)
    );
    
    if (fileData == MAP_FAILED) {
        cerr << "Memory mapping failed." << endl;
        close(fd);
        return 1;
    }

    vector<thread> threads;
    vector<WordMap> localMaps(numThreads);
    size_t chunkSize = fileSize / numThreads;

    for (int t = 0; t < numThreads; t++) {
        size_t startIdx = t * chunkSize;
        size_t endIdx = (t == numThreads - 1) ? fileSize : startIdx + chunkSize;
        
        threads.emplace_back(
            processChunk, 
            fileData, 
            startIdx, 
            endIdx, 
            fileSize, 
            ref(localMaps[t])
        );
    }

    for (auto& thread : threads) {
        thread.join();
    }

    munmap(const_cast<char*>(fileData), fileSize);
    close(fd);

    WordMap globalMap;
    for (int t = 0; t < numThreads; ++t) {
        for (const auto& [word, count] : localMaps[t]) {
            globalMap[word] += count;
        }
    }

    vector<pair<string, uint64_t>> sortedWords(
        globalMap.begin(), globalMap.end()
    );

    sort(sortedWords.begin(), sortedWords.end(), 
        [](const auto& a, const auto& b) {
            return a.second > b.second; 
        }
    );

    ofstream csvFile(outputPath);
    if (!csvFile.is_open()) {
        cerr << "Could not open output CSV file." << endl;
    }
    else {
        csvFile << "Word,Count\n";
        for (const auto& [word, count] : sortedWords) {
            csvFile << word << "," << count << "\n";
        }
        csvFile.close();
    }
    auto endTime = chrono::high_resolution_clock::now();
    auto duration = chrono::duration_cast<chrono::milliseconds>(endTime - startTime).count();
    cout << "Word counting completed in " << duration << " ms." << endl;

    return 0;
}
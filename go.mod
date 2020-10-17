module github.com/cloudreach/container-base-terratest

go 1.13

require (
	github.com/google/uuid v1.1.1 // indirect
	github.com/gruntwork-io/terratest v0.19.1
	github.com/magefile/mage v1.9.0 // indirect
	github.com/magiconair/properties v1.8.1 // indirect
	github.com/matryer/is v1.2.0
	github.com/stretchr/testify v1.4.0 // indirect
	golang.org/x/crypto v0.0.0-20190926114937-fa1a29108794 // indirect
	golang.org/x/net v0.0.0-20190926025831-c00fd9afed17 // indirect
)

replace github.com/cloudreach/container-base-terratest => ./dry

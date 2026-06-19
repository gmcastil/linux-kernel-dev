#include <stdio.h>

struct device_ops {
	int (*read)(char *buf, size_t size);
	int (*write)(char *buf, size_t size);
};

struct device {
	const struct device_ops *ops;
	char *name;
};

int serial_read(char *buf, size_t size)
{
	printf("serial read: %d bytes\n", (int)size);
	return size;
}

int serial_write(char *buf, size_t size)
{
	printf("serial write: %d bytes\n", (int)size);
	return size;
}

int null_read(char *buf, size_t size)
{
	printf("null read: 0 bytes\n");
	return 0;
}

int null_write(char *buf, size_t size)
{
	printf("null write: 0 bytes\n");
	return size;
}

void dispatch(struct device *dev, char *buf, size_t size)
{
	if (!dev) {
		printf("Error: Null pointer found\n");
		return;
	}
	printf("Dispatching device: %s\n", dev->name);
	dev->ops->read(buf, size);
	dev->ops->write(buf, size);
	return;
}

static const struct device_ops serial_ops = {
	.read = serial_read,
	.write = serial_write,
};

static const struct device_ops null_ops = {
	.read = null_read,
	.write = null_write,
};

int main()
{
	struct device serial_dev;
	struct device null_dev;

	serial_dev.ops = &serial_ops;
	serial_dev.name = "serial";

	null_dev.ops = &null_ops;
	null_dev.name = "null";

	dispatch(&serial_dev, "serial buffer that should be 16 long", 16);
	dispatch(&null_dev, "null buffer that should be 16 long", 16);

	return 0;
}

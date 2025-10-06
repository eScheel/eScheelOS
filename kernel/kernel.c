
void kernel_main()
{
    char* video_ptr = (char*)0xb8000;
    
    *video_ptr++ = 'S';
    *video_ptr++ = 0x1f;
}
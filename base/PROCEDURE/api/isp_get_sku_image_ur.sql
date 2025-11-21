SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc: lsp_WM_Get_SKU_Image_URL                                */
/* Creation Date: 11-Sep-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Return Multiple URL Link for SKU Image                      */
/*                                                                      */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2023-04-5   yeekung  1.0   TPS-667 Created                           */
/************************************************************************/
CREATE   PROC [API].[isp_Get_SKU_Image_UR]
     @c_Storerkey          NVARCHAR(15)
   , @c_SKU                NVARCHAR(20)
   , @c_UserName           NVARCHAR(128) =''
   , @b_Success            INT = 1           OUTPUT
   , @n_err                INT = 0           OUTPUT
   , @c_ErrMsg             NVARCHAR(255)= '' OUTPUT
   , @c_SKUImageURL        NVARCHAR(MAX)= '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt       INT
         , @n_Continue        INT
         , @c_SQL             NVARCHAR(2000)
         , @c_SQL_Parm        NVARCHAR(2000)

   DECLARE @c_SkuImageServer  NVARCHAR(215),
           @c_CustStoredProc  NVARCHAR(100) = '',
           @c_ImageFolder     NVARCHAR(200) = '',
           @c_SKUFolder       NVARCHAR(1000) = '',
           @c_ImageFile       NVARCHAR(255)  = '',
           @n_ID             INT            = 0,
           @c_Fullpath        NVARCHAR(MAX) = '', -- \\172.27.241.21\sgp\SGP-LFL\OPS\ASRS\SyncMe\PRSG\SKU\004042\PRSG_SKU_004042_20160607-122931534.jpg'
           @c_Encrypted       NVARCHAR(MAX) = '',
           @c_Urlencoded      NVARCHAR(MAX) = '',
           @c_Urltemplate     NVARCHAR(2000)= ''

   DECLARE @t_ImageFolder     TABLE
            ( ImageFolder        NVARCHAR(20)  NOT NULL PRIMARY KEY
            )

   SET @c_SKUImageURL = ''
   SET @c_SkuImageServer = ''
   SELECT @c_SkuImageServer = NSQLDescrip
   FROM NSQLCONFIG (NOLOCK)
   WHERE ConfigKey='SkuImageServer'
   AND NSQLValue='1'


   SELECT @c_Urltemplate    = Option5        --URL Template  
   FROM StorerConfig (NOLOCK)
   WHERE ConfigKey='GetSKUURL'
   AND Storerkey = 'ALL'
   AND SValue > ''
   --AND Option1 <> ''                       --Wan03. Use NSQLCOnfig as Option1 not able to store all
   AND Option5 <> ''


   IF ISNULL(@c_SkuImageServer,'') <> ''
   BEGIN
      IF OBJECT_ID('tempdb..#DirTree') IS NULL
      BEGIN      
         CREATE TABLE #DirTree (
            Id int identity(1,1),
            ImagePath NVARCHAR(200) NULL,       --(Wan02) 2020-11-24
            ImageFile nvarchar(255),
            Depth smallint,
            FileFlag bit  -- 0=folder 1=file
            )          
      END

      IF OBJECT_ID('tempdb..#SKUURL') IS NULL
      BEGIN      
         CREATE TABLE #SKUURL (
            Id         INT IDENTITY(1,1),
            [ImageURL] NVARCHAR(1000) -- 0=folder 1=file
            )          
      END

      IF RIGHT(@c_SkuImageServer,1) <> '\'  
      BEGIN
         SET @c_SkuImageServer = @c_SkuImageServer + '\'
      END

      SET @c_SKUImageURL = ''
      SET @c_ImageFolder = ''

      INSERT INTO @t_ImageFolder ( ImageFolder )
      SELECT ImageFolder = ISNULL(RTRIM(SKU.ImageFolder),'')
      FROM SKU WITH (NOLOCK)
      WHERE SKU.Storerkey = @c_Storerkey
      AND SKU.Sku = @c_Sku
      AND SKU.ImageFolder <> '' AND SKU.ImageFolder IS NOT NULL 
      UNION
      SELECT ImageFolder = ISNULL(RTRIM(SIMG.ImageFolder),'')
      FROM SkuImage SIMG  WITH (NOLOCK)
      WHERE SIMG.Storerkey = @c_Storerkey
      AND SIMG.Sku = @c_Sku
      AND SIMG.ImageFolder <> '' AND SIMG.ImageFolder IS NOT NULL 
      ORDER BY ImageFolder


      SET @c_ImageFolder = ''
      -- Loop to get all folder that contains the sku Image
      WHILE  1= 1 --@n_SubFolder_SeqNo > 0  
      BEGIN
         SELECT TOP 1 @c_ImageFolder = ImageFolder
         FROM @t_ImageFolder  
         WHERE ImageFolder > @c_ImageFolder
         ORDER BY ImageFolder

         IF @@ROWCOUNT = 0 OR @c_ImageFolder = ''
            BREAK

         --SET @c_FolderSeqNo = RIGHT('000' +  CONVERT(NVARCHAR(3), @n_SubFolder_SeqNo),3)   
         --SET @c_SKUFolder = @c_SkuImageServer + @c_Storerkey + '\' + @c_ImagePrefix + @c_FolderSeqNo  + '\'
         SET @c_SKUFolder = @c_SkuImageServer + @c_Storerkey + '\' + @c_ImageFolder  + '\'

         INSERT INTO #DirTree (ImageFile, Depth, FileFlag)
         EXEC master..xp_dirtree @c_SKUFolder, 1, 1    --folder, depth 0=all(default) 1..x, 0=not list file(default) 1=list file 

         SET @n_ID = SCOPE_IDENTITY()
      
         UPDATE #DirTree 
         SET ImagePath = @c_SKUFolder 
         WHERE ID <= @n_ID  
            AND ImagePath IS NULL      
         --SET @n_SubFolder_SeqNo = @n_SubFolder_SeqNo - 1
      END 
      --(Wan02) 2020-11-24 - END

      DECLARE IMG_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT ImageFile
               ,ImagePath                                         --(Wan02) 2020-11-24
         FROM #DirTree
         WHERE Depth = 1
         AND FileFlag = 1
         AND ImageFile Like @c_Sku + '.%'
         UNION
         SELECT ImageFile
               ,ImagePath                                         --(Wan02) 2020-11-24
         FROM #DirTree
         WHERE Depth = 1
         AND FileFlag = 1
         AND ImageFile Like @c_Sku + '{%'

      OPEN IMG_CUR
               
      FETCH NEXT FROM IMG_CUR INTO @c_ImageFile, @c_SKUFolder     --(Wan02) 2020-11-24
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_fullpath = @c_SKUFolder + @c_imagefile
         
         SET @c_encrypted = master.dbo.[fnc_CryptoEncrypt](@c_fullpath, '')

         EXEC master.dbo.isp_URLEncode
            @c_encrypted,
            @c_urlencoded  OUTPUT,
            @c_errmsg  OUTPUT

         INSERT INTO #SKUURL (ImageURL) VALUES ( @c_urltemplate + @c_urlencoded ) 
               
         FETCH NEXT FROM IMG_CUR INTO @c_imagefile, @c_SKUFolder     --(Wan02) 2020-11-24
      END
      CLOSE IMG_CUR
      DEALLOCATE IMG_CUR       

      IF NOT EXISTS ( SELECT 1
                     FROM #SKUURL AS s WITH(NOLOCK)
                     )
      BEGIN
         SET @c_SKUImageURL = ''
      END
      ELSE
      BEGIN
           SELECT   @c_SKUImageURL = s.ImageURL 
            FROM #SKUURL AS s WITH(NOLOCK)
            ORDER BY s.Id 
      END
   END
   IF @c_SKUImageURL = ''
   BEGIN
      SELECT  @c_SKUImageURL= 'https://intranetapi.lfuat.net/GenericAPI/GetFile?src=IcOC6d%2BAoBNa16e0gLVR7PS6th0bgaLCsPIZ9M4UmX2CNC%2Fz69UrlCEmIguGHETX%2Bo1U7b8omrkl%2Bw9qT75BasN0VsuVylaxFaAgqXjo%2FlpuCd15Vao%2B6xpSHzVX1LVQzEk2HRWABiY%3D'
   END

   EXIT_SP:
END -- procedure

SET QUOTED_IDENTIFIER OFF

GO
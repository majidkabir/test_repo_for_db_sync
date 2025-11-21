SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: lsp_PRSG_SKU_URL                                        */
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
/* 13-Mar-2020 Shong    1.1   Adding 2 new parameters:                  */
/*                            1) Return Type ROWS/PARAM                 */
/*                            2) If Return Type = PARAM Return Value    */ 
/* 2021-05-21  Wan01    1.2   LFWM-2799 -UATCN SKU Image not loading    */
/* 2020-11-24  Wan02    1.3   LFWM-2824 - UATMulti SKU Image Upload and */
/*                            Display (Backend)                         */   
/* 2021-08-23  Wan03    1.4   LFWM-2989 - CN UATSKU IMAGE GET URL CR for*/
/*                            CN Alicloud migration                     */
/************************************************************************/
CREATE PROC [WM].[lsp_PRSG_SKU_URL]
     @c_Storerkey  NVARCHAR(15)
   , @c_SKU        NVARCHAR(20)
   , @c_UserName   NVARCHAR(128) = ''   
   , @b_Success    INT = 1           OUTPUT  
   , @n_err        INT = 0           OUTPUT                                                                                                             
   , @c_ErrMsg     NVARCHAR(255)= '' OUTPUT   
   , @c_ReturnType NVARCHAR(10) = 'ROW'
   , @c_ReturnURL  NVARCHAR(1000) = '' OUTPUT     
AS
BEGIN
   SET NOCOUNT ON
   
   DECLARE @c_SkuImageServer  NVARCHAR(215)  = '', 
           @c_SKUImageURL     NVARCHAR(1000) = '', 
           @c_SKUFolder       NVARCHAR(1000) = '',
           @c_ImageFile       NVARCHAR(255)  = '',

           @n_ID              INT            = 0   --(Wan02) 2020-11-24


   DECLARE @c_Fullpath        NVARCHAR(MAX) = '' -- \\172.27.241.21\sgp\SGP-LFL\OPS\ASRS\SyncMe\PRSG\SKU\004042\PRSG_SKU_004042_20160607-122931534.jpg'
         , @c_Encrypted       NVARCHAR(MAX) = ''
         , @c_Urlencoded      NVARCHAR(MAX) = ''
         , @c_Urltemplate     NVARCHAR(2000)= ''--'https://intranetapi.lfuat.net/GenericAPI/GetFile?src='
         , @c_ImageFolder     NVARCHAR(200) = ''

   --(Wan02) 2020-11-24 
   DECLARE @t_ImageFolder     TABLE
         ( ImageFolder        NVARCHAR(20)  NOT NULL PRIMARY KEY
         )
   --(Wan02) 2020-11-24 
   DECLARE @n_SubFolder_SeqNo INT = 0
         , @c_ImagePrefix     NVARCHAR(2) = ''
         , @c_FolderSeqNo     NVARCHAR(3) = ''           
   SET @c_SKUImageURL = ''
   SET @c_SkuImageServer = ''
                                             --Wan03. Use NSQLCOnfig as Option1 not able to store all, in this case set option1 as blank
   SELECT @c_SkuImageServer = Option1        --NETAPP Volume Shared Path. Should be same nsqlconfig 'SkuImageServer' nsqldescrip-- Wan03 
        , @c_Urltemplate    = Option5        --URL Template  
   FROM StorerConfig (NOLOCK)
   WHERE ConfigKey='GetSKUURL'
   AND Storerkey = 'ALL'
   AND SValue > ''
   --AND Option1 <> ''                       --Wan03. Use NSQLCOnfig as Option1 not able to store all
   AND Option5 <> ''
   
   --(Wan03) - START
   IF @c_SkuImageServer = ''
   BEGIN
      SELECT @c_SkuImageServer = n.NSQLDescrip  --NETAPP Volume Shared Path
      FROM dbo.NSQLCONFIG AS n (NOLOCK)
      WHERE n.ConfigKey='SkuImageServer'
      AND n.NSQLValue='1'
   END
   --(Wan03) - END
   
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
    
   IF @c_SkuImageServer = ''   
   BEGIN
      GOTO QUIT      
   END
       
   IF RIGHT(@c_SkuImageServer,1) <> '\'  
   BEGIN
      SET @c_SkuImageServer = @c_SkuImageServer + '\'
   END

   SET @c_SKU = RTRIM(@c_SKU) 
   SET @c_ImageFolder = ''

   --(Wan02) 2020-11-24 - START
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
             
   --IF @c_ImageFolder = ''
   --BEGIN
   --   GOTO QUIT
   --END
 
   --SET  @c_ImagePrefix= LEFT(@c_ImageFolder,2)
   --SET @n_SubFolder_SeqNo = CONVERT(INT,SUBSTRING(@c_ImageFolder,3,3))  

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
      
      UPDATE #DirTree SET ImagePath = @c_SKUFolder 
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

      IF @c_ReturnType = 'PARAM'
      BEGIN
         SET @c_ReturnURL =  @c_urltemplate + @c_urlencoded
         BREAK                   
      END
      ELSE
      BEGIN
         INSERT INTO #SKUURL (ImageURL) VALUES ( @c_urltemplate + @c_urlencoded ) 
      END     
               
      FETCH NEXT FROM IMG_CUR INTO @c_imagefile, @c_SKUFolder     --(Wan02) 2020-11-24
   END
   CLOSE IMG_CUR
   DEALLOCATE IMG_CUR       

   QUIT:

   IF @c_ReturnType <> 'PARAM'
   BEGIN
      SELECT @c_Storerkey AS [StorerKey], 
               @c_SKU     AS [SKU],
               s.ImageURL 
      FROM #SKUURL AS s WITH(NOLOCK)
      ORDER BY s.Id 
   END        
               
END -- Procedure

GO
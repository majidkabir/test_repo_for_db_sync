SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: lsp_PRSG_ASN_URL                                        */
/* Creation Date: 2021-10-06                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Return Multiple URL Link for ASN Image                      */
/*        : LFWM-2020 - SIT  ASN image upload SP Issue                  */
/*                                                                      */
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
/* 2021-10-06  Wan      1.0   Created.                                  */
/* 2021-10-06  Wan      1.1   DevOps Combine Script                     */
/* 2023-07-11  Wan01    1.2   LFWM-2145 - UAT - TW  Unknown error when  */
/*                            uploading Image to ASN                    */
/*                            Devops Comnined Script                    */
/************************************************************************/
CREATE   PROC [WM].[lsp_PRSG_ASN_URL]
     @c_Storerkey          NVARCHAR(15)  -- Required
   , @c_ReceiptKey         NVARCHAR(10)  -- Required 
   , @c_UserName           NVARCHAR(128) =''         
   , @b_Success            INT = 1           OUTPUT  
   , @n_err                INT = 0           OUTPUT                                                                                                             
   , @c_ErrMsg             NVARCHAR(255)= '' OUTPUT   
AS
BEGIN
   SET NOCOUNT ON
   
   DECLARE @n_Continue           INT= 1
   
   DECLARE @c_ASNImageServer     NVARCHAR(215)  = '' 
         , @c_ASNImageURL        NVARCHAR(1000) = '' 
         , @c_ASNFolder          NVARCHAR(1000) = ''
         , @c_ImageFolder        NVARCHAR(255)  = ''          
         , @c_ImageFile          NVARCHAR(255)  = '' 


   DECLARE @c_FullPath           NVARCHAR(MAX) = '' 
         , @c_Encrypted          NVARCHAR(MAX) = ''
         , @c_URLEncoded         NVARCHAR(MAX) = ''
         , @c_URLTemplate        NVARCHAR(2000)= '' --UAT:'https://intranetapi.lfuat.net/GenericAPI/GetFile?src=', PRD:'https://intranetapi.lfapps.net/GenericAPI/GetFile?src='
         
         , @c_ContainerKey       NVARCHAR(18)  = ''
         , @c_POKey              NVARCHAR(18)  = ''
         
         , @c_Country            NVARCHAR(3)    = ''
         , @c_GetASNURL_Option5  NVARCHAR(4000) = '' 
         
         , @CUR_DirTreeFolder    CURSOR
         , @CUR_DirTreeFile      CURSOR
         
    DECLARE @t_Folder            TABLE                                              --(Wan01)
         ( RowID                 INT   IDENTITY(1,1) PRIMARY KEY
         , FolderName            NVARCHAR(100) NOT NULL DEFAULT('')
         )     
               
   SET @c_ASNImageURL = ''
   SET @c_ASNImageServer = ''
   
   SELECT @c_GetASNURL_Option5 = sc.Option5        --URL Template  
   FROM dbo.StorerConfig AS sc WITH (NOLOCK)
   WHERE sc.ConfigKey='GetASNURL'
   AND sc.Storerkey = 'ALL'
   AND sc.SValue > ''
   
   --SET @c_Country = ''                                                            --(Wan01) - STaRT
   --SELECT @c_Country = dbo.fnc_GetParamValueFromString('@c_Country', @c_GetASNURL_Option5, @c_Country) 
   
   --IF @c_Country = ''
   --BEGIN
   --   SET @n_Continue = 3
   --   SET @n_Err = 99999
   --   SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(6), @n_Err) + ': Country Folder Not Setup. (lsp_PRSG_ASN_URL)'
   --   GOTO EXIT_SP
   --END                                                                            (Wan01) - END
   
   SET @c_URLTemplate = ''
   SELECT @c_URLTemplate = dbo.fnc_GetParamValueFromString('@c_URLTemplate', @c_GetASNURL_Option5, @c_URLTemplate) 
   
   IF @c_URLTemplate = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 561801
      SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(6), @n_Err) + ': API URL Not Setup. (lsp_PRSG_ASN_URL)'
      GOTO EXIT_SP
   END

   SELECT @c_ASNImageServer = n.NSQLDescrip  --NETAPP Volume Shared Path  
   FROM dbo.NSQLCONFIG AS n (NOLOCK)  
   WHERE n.ConfigKey='ASNImageServer'  
   AND n.NSQLValue='1'  
      
   IF OBJECT_ID('tempdb..#DirTreeFolder') IS NULL
   BEGIN      
      CREATE TABLE #DirTreeFolder (
         Id          INT IDENTITY(1,1)
      ,  FolderName  NVARCHAR(255)
      ,  Depth       SMALLINT
      ,  FileFlag    BIT  -- 0=folder 1=file
         )          
   END
   
   IF OBJECT_ID('tempdb..#DirTreeFile') IS NULL
   BEGIN      
      CREATE TABLE #DirTreeFile (
         Id          INT   IDENTITY(1,1)
      ,  ImageFile   NVARCHAR(255)
      ,  Depth       SMALLINT
      ,  FileFlag    BIT  -- 0=folder 1=file
         )          
   END

   IF OBJECT_ID('tempdb..#ASNURL') IS NULL
   BEGIN      
      CREATE TABLE #ASNURL (
         Id         INT IDENTITY(1,1),
         [ImageURL] NVARCHAR(1000) -- 0=folder 1=file
         )          
   END
   
   SELECT @c_ContainerKey = ISNULL(r.ContainerKey,'') 
         ,@c_POKey        = ISNULL(r.POKey,'')
   FROM dbo.RECEIPT AS r WITH (NOLOCK)
   WHERE r.StorerKey = @c_Storerkey
   AND r.ReceiptKey = @c_ReceiptKey
   
   --SET @c_ASNFolder = @c_ASNImageServer + '\' + @c_Country + '\' + @c_Storerkey + '\IN'          --(Wan01)   
   SET @c_ASNFolder = @c_ASNImageServer + '\' + @c_Storerkey + '\IN'                               --(Wan01) Setup country in System Config
    
   INSERT INTO #DirTreeFolder (FolderName, Depth, FileFlag)
   EXEC master..xp_dirtree @c_ASNFolder, 1, 1    --folder, depth 0=all(default) 1..x, 0=not list file(default) 1=list file 
   
   IF @c_ReceiptKey <> ''                                                           --(Wan01) - START
   BEGIN
      INSERT INTO @t_Folder ( FolderName )
      SELECT dtf.FolderName   
      FROM #DirTreeFolder AS dtf  
      WHERE dtf.FileFlag  = 0 
      AND dtf.FolderName LIKE '%' + @c_ReceiptKey +'%' 
   END 
   
   IF @c_ContainerKey <> ''
   BEGIN
      INSERT INTO @t_Folder ( FolderName )
      SELECT dtf.FolderName   
      FROM #DirTreeFolder AS dtf  
      WHERE dtf.FileFlag  = 0 
      AND dtf.FolderName LIKE '%' + @c_ContainerKey +'%' 
   END 
   
   IF @c_POKey <> ''
   BEGIN
      INSERT INTO @t_Folder ( FolderName )
      SELECT dtf.FolderName   
      FROM #DirTreeFolder AS dtf  
      WHERE dtf.FileFlag  = 0 
      AND dtf.FolderName LIKE '%' + @c_POKey +'%' 
   END 
   
   SET @CUR_DirTreeFolder = CURSOR FAST_FORWARD READ_ONLY FOR  
   SELECT tf.FolderName 
   FROM @t_Folder AS tf
   ORDER BY tf.RowID  
   --SELECT dtf.FolderName 
   --FROM #DirTreeFolder AS dtf
   --WHERE dtf.FileFlag  = 0
   --AND ( dtf.FolderName LIKE '%' + @c_ContainerKey +'%' OR
   --      dtf.FolderName LIKE '%' + @c_POKey +'%' OR
   --      dtf.FolderName LIKE '%' + @c_ReceiptKey +'%')                            --(Wan01) - END
   
   OPEN @CUR_DirTreeFolder 
    
   FETCH NEXT FROM @CUR_DirTreeFolder INTO @c_ImageFolder 

   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SET @c_ImageFolder = @c_ASNFolder + '\' + @c_ImageFolder
      
      --Get all files from folder
      TRUNCATE TABLE #DirTreeFile;
      INSERT INTO #DirTreeFile (ImageFile, Depth, FileFlag)
      EXEC master..xp_dirtree @c_ImageFolder, 1, 1
      
      SET @CUR_DirTreeFile = CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT dtf.ImageFile
      FROM #DirTreeFile AS dtf
      WHERE dtf.FileFlag = 1

      OPEN @CUR_DirTreeFile
               
      FETCH NEXT FROM @CUR_DirTreeFile INTO @c_ImageFile
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_FullPath = @c_ImageFolder + '\' + @c_ImageFile
            
         SET @c_encrypted = master.dbo.[fnc_CryptoEncrypt](@c_FullPath, '')

         EXEC master.dbo.isp_URLEncode
               @c_Encrypted
            ,  @c_URLEncoded  OUTPUT
            ,  @c_ErrMsg      OUTPUT

         INSERT INTO #ASNURL (ImageURL) VALUES ( @c_URLTemplate + @c_URLEncoded )   
         
         FETCH NEXT FROM @CUR_DirTreeFile INTO @c_ImageFile
      END
      CLOSE @CUR_DirTreeFile
      DEALLOCATE @CUR_DirTreeFile   
      
      FETCH NEXT FROM @CUR_DirTreeFolder INTO @c_ImageFolder 
   END
   CLOSE @CUR_DirTreeFolder
   DEALLOCATE @CUR_DirTreeFolder            

   EXIT_SP:
   SELECT @c_ReceiptKey AS ReceiptKey 
         ,s.Id
         ,s.ImageURL 
   FROM #ASNURL AS s WITH(NOLOCK)
   ORDER BY s.Id     
               
END -- Procedure

GO
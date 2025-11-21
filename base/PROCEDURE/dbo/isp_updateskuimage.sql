SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_UpdateSkuImage                                 */
/* Creation Date: 17-Apr-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Generate and update Sku Image Path. Move image form upload  */
/*          folder to assigned sub-folder                               */
/*                                                                      */
/* Called By: Sku Maintenance                                           */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 13-Nov-2015  NJOW01  1.0   Fix folder and file searching             */
/* 06-Feb-2017  TLTING  1.1   debug flag                                */
/* 06-AUG-2020  Wan01   1.2   LFWM-2824 - UATMulti SKU Image Upload and */
/*                            Display (Backend)                         */
/* 08-JUL-2022  NJOW02  1.3   Add sku image file upload logging         */
/* 08-JUL-2022  NJOW02  1.3   DEVOPS Combine script                     */
/* 08-JUN-2023  Wan02   1.4   LFWM-4273 - PROD & UAT - TH UQNMD - SCE   */
/*                            Image Upload-not show photo after uploaded*/
/*                            - Fix: Extend @c_Sku to 20 Chars          */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_UpdateSkuImage]
   @c_storerkey NVARCHAR(15),
   @b_success   INT OUTPUT,
   @n_err       INT OUTPUT,
   @c_errmsg    NVARCHAR(225) OUTPUT
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  INT,
           @n_starttcnt INT,
           @n_cnt INT,
           @n_pos INT,
           @c_SkuImageServer     NVARCHAR(200),          
           @c_SkuImageUploadPath NVARCHAR(200),
           @c_SkuImagePath       NVARCHAR(200),
           @c_SkuImageFileFrom   NVARCHAR(200),
           @c_SkuImageFileTo     NVARCHAR(200),
           @c_NSQLValue NVARCHAR(30),
           @c_ImageFile NVARCHAR(255),
           @c_Sku NVARCHAR(20),                                                     --(Wan02)
           @c_FileExt NVARCHAR(3),
           @c_ToSubFolder NVARCHAR(200),
           @c_Lastsubfolder NVARCHAR(200),
           @c_sku_image_subfolder NVARCHAR(200),
           @c_sku_image NVARCHAR(200),
           @c_FolderSeqNo NVARCHAR(3),
           @c_CreateDirTree NCHAR(1),
           @n_debug     INT   
   DECLARE @c_SkuImageFile NVARCHAR(50)   = ''  --(Wan01)
         , @n_SImgFound INT = 0                 --(Wan01)                
              
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0, @c_CreateDirTree = 'N' 
   SET @n_debug = 0
     
   IF ISNULL(@c_storerkey,'') = ''
   BEGIN
      SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60001   
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Empty Storer Parameter. (isp_UpdateSkuImage)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO ENDPROC
   END

   --(Wan01) - START
   IF OBJECT_ID('tempdb..#TMP_SUBFOLDERCNT','u') IS NOT NULL
   BEGIN 
      DROP TABLE #TMP_SUBFOLDERCNT
   END 
   
   CREATE TABLE #TMP_SUBFOLDERCNT
      (  RowRef   INT   NOT NULL IDENTITY(1,1) PRIMARY KEY
      ,  ImageFolder NVARCHAR(5) NOT NULL DEFAULT('')
      ,  NoofSku     INT         NOT NULL DEFAULT(0)
      )
   --(Wan01) - END
   

   SELECT @c_SkuImageServer = ISNULL(NSQLDescrip,''),
          @c_NSQLValue = ISNULL(NSQLValue,'')
   FROM NSQLCONFIG (NOLOCK)     
   WHERE ConfigKey='SkuImageServer' 
         
   IF ISNULL(@c_SkuImageServer,'') = '' OR @c_NSQLValue <> '1'
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60002   
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Sku Image Server Not Yet Setup/Enable In System Config. (isp_UpdateSkuImage)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
   END   

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      BEGIN TRAN                                      
   
      IF RIGHT(RTRIM(@c_SkuImageServer),1) <> '\' 
         SET @c_SkuImageServer = RTRIM(@c_SkuImageServer) + '\'

      SELECT @c_SkuImageUploadPath = RTRIM(@c_SkuImageServer) + LTRIM(@c_storerkey)
      
      IF @n_debug = 1
      BEGIN
         SELECT 'SkuImageUploadPath' = @c_SkuImageUploadPath 
      END
  
      IF OBJECT_ID('tempdb..#DirTree') IS NULL
      BEGIN      
         CREATE TABLE #DirTree (
           Id int identity(1,1),
           SubDirectory nvarchar(255),
           Depth smallint,
           FileFlag bit  -- 0=folder 1=file
          )
         
         INSERT INTO #DirTree (SubDirectory, Depth, FileFlag)
         EXEC master..xp_dirtree @c_SkuImageServer, 2, 1    --folder, depth 0=all(default) 1..x, 0=not list file(default) 1=list file 
         
         SELECT @c_CreateDirTree = 'Y'         
      END

      IF @n_debug = 1
      BEGIN
         Print 'xp_dirtree 1'  
      END

      IF NOT EXISTS (SELECT 1 FROM #DirTree 
                     WHERE SubDirectory = @c_storerkey
                     AND Depth = 1) 
      BEGIN
          EXEC master.dbo.xp_create_subdir @c_SkuImageUploadPath
      END
      IF @n_debug = 1
      BEGIN
         Print 'xp_create_subdir 1'  
      END    
      
      --NJOW01
      IF OBJECT_ID('tempdb..#DirTreeStorer') IS NULL
      BEGIN      
         CREATE TABLE #DirTreeStorer (
           Id int identity(1,1),
           SubDirectory nvarchar(255),
           Depth smallint,
           FileFlag bit  -- 0=folder 1=file
          )
                  
         INSERT INTO #DirTreeStorer (SubDirectory, Depth, FileFlag)
         EXEC master..xp_dirtree @c_SkuImageUploadPath, 2, 1    --folder, depth 0=all(default) 1..x, 0=not list file(default) 1=list file    
      END
                            
      --DELETE FROM #DirTree
      --INSERT INTO #DirTree (SubDirectory, Depth, FileFlag)
      --EXEC master..xp_dirtree @c_SkuImageUploadPath, 1, 1   
      
      --IF EXISTS (SELECT 1 FROM #DirTree WHERE Depth = 2 AND FileFlag = 1 )
      IF EXISTS (SELECT 1 FROM #DirTreeStorer WHERE Depth = 1 AND FileFlag = 1 ) --NJOW01
      BEGIN
         INSERT INTO #TMP_SUBFOLDERCNT ( ImageFolder, NoofSku )   -- (Wan01)
         SELECT ImageFolder = RIGHT(SKU.ImageFolder,5)            -- (Wan01)
              , Count(SKU.Sku) AS NoofSku
         FROM SKU(NOLOCK)
         WHERE Storerkey = @c_Storerkey
         AND ISNULL(SKU.ImageFolder,'') <> ''
         GROUP BY RIGHT(SKU.ImageFolder,5)                        -- (Wan01)
      END   
 
      DECLARE IMG_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT  SubDirectory
                --(Wan01) - START
               , Sku = CASE WHEN CHARINDEX( '{', SubDirectory, 1) > 0 AND CHARINDEX( '{', SubDirectory, 1) < CHARINDEX( '.', SubDirectory, 1)   
                            THEN SUBSTRING(SubDirectory,1, CHARINDEX( '{', SubDirectory, 1) - 1)
                            WHEN CHARINDEX( '{', SubDirectory, 1) = 0
                            THEN SUBSTRING(SubDirectory,1, CHARINDEX( '.', SubDirectory, 1) - 1)
                            END
               , SkuImageFile = SUBSTRING(SubDirectory,1, CHARINDEX( '.', SubDirectory, 1) - 1)
                --(Wan01) - END
         FROM #DirTreeStorer --NJOW01
         --FROM #DirTree
         WHERE Depth = 1 --NJOW01
         --WHERE Depth = 2
         AND FileFlag = 1
         AND CHARINDEX( '.', SubDirectory, 1) > 0                             --(Wan01) 

      OPEN IMG_CUR
               
      FETCH NEXT FROM IMG_CUR INTO @c_imagefile, @c_Sku, @c_SkuImageFile   --(Wan01)
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @c_fileext = '', @c_ToSubFolder = '', @c_LastSubFolder = '', @c_SkuImagePath = ''  --(Wan01)
         --SELECT @n_pos = CHARINDEX('.', @c_imagefile)                       --(Wan01)
          
         --IF @n_pos > 0 --valid file name                                    --(Wan01)       
         --BEGIN                                                              --(Wan01)
            --SELECT @c_sku = LEFT(@c_imagefile, @n_pos - 1)                  --(Wan01)
            --SELECT @c_fileext = SUBSTRING(@c_imagefile, @n_pos + 1, 3)      --(Wan01)
            --(Wan01) - START
        
            SET @n_SImgFound = 0        
            SELECT @c_sku_image = ISNULL(SIMG.ImageFile,'')
                 , @c_sku_image_subfolder = ISNULL(SIMG.ImageFolder,'')
                 , @n_SImgFound = 1
            FROM SKUIMAGE SIMG WITH (NOLOCK) 
            WHERE SIMG.Storerkey = @c_Storerkey
            AND SIMG.Sku = @c_sku
            AND SIMG.ImageFile = @c_imagefile

            SET @n_cnt = @@ROWCOUNT

            IF @n_cnt = 0 --AND @c_SkuImageFile = @c_Sku     
            BEGIN
               SELECT @c_sku_image = ISNULL(SKU.Busr4,''),
                      @c_sku_image_subfolder = ISNULL(SKU.ImageFolder,'')
               FROM SKU(NOLOCK) 
               WHERE Storerkey = @c_Storerkey
               AND Sku = @c_sku

               SELECT @n_cnt = @@ROWCOUNT

               IF @c_SkuImageFile = @c_Sku 
               BEGIN
                  SET @n_SImgFound = 1
               END
               ELSE
               BEGIN
                  SET @c_sku_image = ''
                  SET @c_sku_image_subfolder = ''
               END
            END 
            --(Wan01) - END   
       
            IF @n_cnt > 0  -- correct sku
            BEGIN
               SELECT @c_SkuImageFileFrom = RTRIM(@c_SkuImageUploadPath) + '\' + LTRIM(@c_imagefile)

               IF @n_debug = 1
               BEGIN
                  SELECT 'SkuImageUploadPath' = @c_SkuImageUploadPath 
               END
                      
               IF @c_sku_image_subfolder = '' --never assign image to subfolder before
               BEGIN
                  -- find existing available sub-folder of same folder group
                  SELECT TOP 1 @c_ToSubFolder = ImageFolder
                  FROM #TMP_SUBFOLDERCNT
                  WHERE LEFT(ImageFolder, 1) = LEFT(@c_sku, 1)   --valid subfolder format A_001, C_023, 0_013  (first char of sku + _ + seq# 
                  AND SUBSTRING(ImageFolder, 2, 1) = '_'
                  AND noofsku < 1000   --maximum image per folder
                  ORDER BY Imagefolder

                  IF ISNULL(@c_ToSubFolder,'') = '' --no available sub_folder
                  BEGIN
                     -- find last used sub-folder of same folder group
                     SELECT TOP 1 @c_LastSubFolder = ImageFolder
                     FROM #TMP_SUBFOLDERCNT
                     WHERE LEFT(ImageFolder, 1) = LEFT(@c_sku, 1)
                     AND SUBSTRING(ImageFolder, 2, 1) = '_'
                     ORDER BY ImageFolder DESC

                     IF ISNULL(@c_LastSubFolder,'') = '' --no last used sub-folder found
                     BEGIN                        
                        SELECT @c_ToSubFolder = LEFT(@c_sku, 1) + '_001'   
                     END
                     ELSE
                     BEGIN
                        SELECT @c_FolderSeqNo = RIGHT('000' + RTRIM(LTRIM(CONVERT(NVARCHAR(3), CAST(SUBSTRING(@c_LastSubFolder, 3, 3) AS INT) + 1))),3)
                        SELECT @c_ToSubFolder = LEFT(@c_sku, 1) + '_' + LTRIM(RTRIM(@c_FolderSeqNo))
                     END  

                     SELECT @c_SkuImagePath = RTRIM(@c_SkuImageServer) + RTRIM(LTRIM(@c_storerkey)) + '\' + @c_ToSubFolder
                     SELECT @c_SkuImageFileTo = RTRIM(@c_SkuImagePath) + '\' + LTRIM(@c_imagefile)

                     INSERT INTO #TMP_SUBFOLDERCNT (ImageFolder, NoofSku) 
                     VALUES (@c_ToSubFolder, 1)

                     --create sub-folder if not exists
                     --IF NOT EXISTS (SELECT 1 FROM #DirTree 
                     IF NOT EXISTS (SELECT 1 FROM #DirTreeStorer --NJOW01 
                                    WHERE SubDirectory = @c_ToSubFolder
                                    AND Depth = 1 --NJOW01
                                    --AND Depth = 2
                                    AND FileFlag = 0) 
                     BEGIN
                        EXEC master.dbo.xp_create_subdir @c_SkuImagePath                        
                     END                                          
                  
                     EXEC isp_MoveFile @c_SkuImageFileFrom OUTPUT, @c_SkuImageFileTo OUTPUT, @b_success OUTPUT

                     /* 
                     IF @b_success <> 1
                     BEGIN 
                        SELECT @n_continue = 3
                        SELECT @n_err = 60090   
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Move Image Failed.' + ' (isp_UpdateSkuImage)'
                     END
                     */
                  END
                  ELSE
                  BEGIN --Sub folder of same group available
                     SELECT @c_SkuImagePath = RTRIM(@c_SkuImageServer) + RTRIM(LTRIM(@c_storerkey)) + '\' + @c_ToSubFolder
                     SELECT @c_SkuImageFileTo = RTRIM(@c_SkuImagePath) + '\' + LTRIM(@c_imagefile)

                     --IF NOT EXISTS (SELECT 1 FROM #DirTree 
                     IF NOT EXISTS (SELECT 1 FROM #DirTreeStorer --NJOW01 
                                    WHERE SubDirectory = @c_ToSubFolder
                                    AND Depth = 1 --NJOW01
                                    --AND Depth = 2
                                    AND FileFlag = 0) 
                     BEGIN
                        EXEC master.dbo.xp_create_subdir @c_SkuImagePath
                     END                     

                     EXEC isp_MoveFile @c_SkuImageFileFrom OUTPUT, @c_SkuImageFileTo OUTPUT, @b_success OUTPUT  

                     /*
                     IF @b_success <> 1
                     BEGIN 
                         SELECT @n_continue = 3
                         SELECT @n_err = 60091  
                         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Move Image Failed.' + ' (isp_UpdateSkuImage)'
                     END
                     */

                     UPDATE #TMP_SUBFOLDERCNT
                     SET noofsku = noofsku + 1
                     WHERE ImageFolder = @c_ToSubFolder 
                  END                  
               END      
               ELSE
               BEGIN --sku alredy have sub-folder
                  SET @c_ToSubFolder = @c_sku_image_subfolder        --(Wan01)
                  SELECT @c_SkuImagePath = RTRIM(@c_SkuImageServer) + RTRIM(LTRIM(@c_storerkey)) + '\' + @c_sku_image_subfolder
                  SELECT @c_SkuImageFileTo = RTRIM(@c_SkuImagePath) + '\' + LTRIM(@c_imagefile)
                 
                  --IF NOT EXISTS (SELECT 1 FROM #DirTree 
                  IF NOT EXISTS (SELECT 1 FROM #DirTreeStorer --NJOW01 
                                 WHERE SubDirectory = @c_sku_image_subfolder
                                 AND Depth = 1
                                 --AND Depth = 2
                                 AND FileFlag = 0) 
                  BEGIN
                     EXEC master.dbo.xp_create_subdir @c_SkuImagePath
                  END                                       

                  EXEC isp_MoveFile @c_SkuImageFileFrom OUTPUT, @c_SkuImageFileTo OUTPUT, @b_success OUTPUT

                  /*
                  IF @b_success <> 1
                  BEGIN 
                         SELECT @n_continue = 3
                         SELECT @n_err = 60092   
                         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Move Image Failed.' + ' (isp_UpdateSkuImage)'
                  END
                  */
               END         
                                                
               IF @c_sku = @c_SkuImageFile   --(Wan01)
               BEGIN
                  UPDATE SKU WITH (ROWLOCK)
                  SET ImageFolder = RTRIM(@c_ToSubFolder) 
                     ,Busr4 = @c_SkuImageFileTo,                                                             
                      TrafficCop = NULL
                  WHERE Storerkey = @c_Storerkey
                  AND Sku = @c_Sku
                  
                  SELECT @n_err = @@ERROR  
                  
                  IF @n_err <> 0  
                  BEGIN  
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 60093   
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update SKU Failed.' + ' (isp_UpdateSkuImage)( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
                     GOTO ENDPROC      --(Wan01)
                  END                  --(Wan01)
               END                     --(Wan01)
               
               --NJOW02
               INSERT INTO UploadSkuImageLog (Storerkey, Sku, ImagePath, ImageFolder, ImageFile, MainImageFlag, LogDate)
               VALUES (@c_Storerkey, @c_Sku, RTRIM(@c_SkuImagePath), RTRIM(@c_ToSubFolder), @c_ImageFile, CASE WHEN @c_sku = @c_SkuImageFile THEN 'Y' ELSE 'N' END, GetDate())                  
                                                           
               --(Wan01)- START
               IF @n_SImgFound = 0 
               BEGIN
                  INSERT INTO SKUIMAGE
                     (  Storerkey
                     ,  Sku
                     ,  ImageFolder
                     ,  ImageFile
                     )
                  VALUES
                     (
                        @c_Storerkey
                     ,  @c_Sku
                     ,  RTRIM(@c_ToSubFolder) 
                     ,  @c_ImageFile
                     ) 
                     
                  SET @n_Err = @@ERROR
                  
                  IF @n_err <> 0  
                  BEGIN  
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 60093   
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': INSERT SKUIMAGE Failed.' + ' (isp_UpdateSkuImage)( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
                     GOTO ENDPROC
                  END 
               END
               --(Wan01)- END                
            --END --(Wan01)            
         END
                 
         FETCH NEXT FROM IMG_CUR INTO @c_imagefile, @c_Sku, @c_SkuImageFile   --(Wan01)
      END
      CLOSE IMG_CUR
      DEALLOCATE IMG_CUR       
   END
      
ENDPROC: 

   IF OBJECT_ID('tempdb..#DirTree') IS NOT NULL AND @c_CreateDirTree = 'Y'
      DROP TABLE #DirTree

   IF OBJECT_ID('tempdb..#DirTreeStorer') IS NOT NULL
      DROP TABLE #DirTreeStorer
 
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
   ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'isp_UpdateSkuImage'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
      
END -- End PROC

GO
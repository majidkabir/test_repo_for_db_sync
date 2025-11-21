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
/* PVCS Version: 1.3                                                    */
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
/* 2021-02-10  mingle01 1.1   Add Big Outer Begin try/Catch             */
/* 2021-02-15  Wan01    1.1   Execute Login if @c_UserName<>SUSER_SNAME()*/
/*                            Return @b_Success=0 if @n_Continue=3      */
/* 2021-05-21  Wan02    1.2   LFWM-2799 -UATCN SKU Image not loading    */
/*                            Do Not Use UserName to login as SubProgram*/
/*                            need to Access to File Server Image Folder*/
/*                            as UserName may not have folder access right*/
/* 2021-08-23  Wan03    1.3   LFWM-2989 - CN UATSKU IMAGE GET URL CR for*/
/*                            CN Alicloud migration                     */
/************************************************************************/
CREATE PROC [WM].[lsp_WM_Get_SKU_Image_URL]
     @c_Storerkey          NVARCHAR(15)
   , @c_SKU                NVARCHAR(20)
   , @c_UserName           NVARCHAR(128) =''   
   , @b_Success            INT = 1           OUTPUT  
   , @n_err                INT = 0           OUTPUT                                                                                                             
   , @c_ErrMsg             NVARCHAR(255)= '' OUTPUT
   , @c_ReturnType         NVARCHAR(10) = 'ROW'  
   , @c_ReturnURL          NVARCHAR(1000) = '' OUTPUT                  
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

   DECLARE @c_NSQLDescrip     NVARCHAR(215), 
           @c_SKUImageURL     NVARCHAR(1000), 
           @c_CustStoredProc  NVARCHAR(100) = ''

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1        --(Wan01)
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @n_Err = 0 
   --(Wan02) - START 
   --Do Not Use UserName to login as SubProgram need to Access to File Server Image Folder as UserName may not have folder access right 
   --(Wan01) - START
   --IF SUSER_SNAME() <> @c_UserName 
   --BEGIN
   --   EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
   
   --   IF @n_Err <> 0 
   --   BEGIN
   --      GOTO EXIT_SP
   --   END
      
   --   EXECUTE AS LOGIN = @c_UserName
   --END
   --(Wan01) - END
   --(Wan02) - END
   --(mingle01) - START
   BEGIN TRY
      SELECT TOP 1 @c_CustStoredProc = ISNULL(SValue,'')
      FROM StorerConfig (NOLOCK)
      WHERE ConfigKey='GetSKUURL'
      AND Storerkey = 'ALL'
      AND SValue > ''
      --AND Option1 <> ''        --(Wan03)
      AND Option5 <> ''
      --AND OPTION5 IS NOT NULL
      
      IF NOT EXISTS ( SELECT 1 
                      FROM dbo.sysobjects WHERE  id = OBJECT_ID(@c_CustStoredProc) 
                      AND OBJECTPROPERTY(id ,N'IsProcedure') = 1 )
      BEGIN
         GOTO URL_STANDARD
      END 
       
      SET @c_SQL = N'EXEC ' +  @c_CustStoredProc  +     
            N'  @c_Storerkey = @c_Storerkey' +     
            N', @c_SKU = @c_SKU ' +     
            N', @c_UserName = @c_UserName' +     
            N', @b_Success = @b_Success OUTPUT ' +       
            N', @n_err = @n_Err OUTPUT ' +      
            N', @c_ErrMsg = @c_ErrMsg OUTPUT ' +
            N', @c_ReturnType = @c_ReturnType ' +
            N', @c_ReturnURL  = @c_ReturnURL OUTPUT '            
                 
      SET @c_SQL_Parm =     
            N'  @c_Storerkey NVARCHAR(15) ' +     
            N', @c_SKU NVARCHAR(20) ' +     
            N', @c_UserName NVARCHAR(128) ' +       
            N', @b_Success INT OUTPUT ' +     
            N', @n_err INT OUTPUT ' +     
            N', @c_ErrMsg NVARCHAR(255) OUTPUT ' +
            N', @c_ReturnType NVARCHAR(10) ' +
            N', @c_ReturnURL  NVARCHAR(1000) OUTPUT '
           
      EXEC sp_ExecuteSQL @c_SQL, @c_SQL_Parm, @c_Storerkey, @c_SKU, @c_UserName, @b_Success OUTPUT
                     , @n_err OUTPUT, @c_ErrMsg OUTPUT, @c_ReturnType, @c_ReturnURL OUTPUT   
      
      GOTO EXIT_SP

      ---  URL_STANDARD ---
      URL_STANDARD:   
      SET @c_SKUImageURL = ''
      SET @c_NSQLDescrip = ''
      SELECT @c_NSQLDescrip = NSQLDescrip
      FROM NSQLCONFIG (NOLOCK)
      WHERE ConfigKey='SkuImageServer'
      AND NSQLValue='1'
      
      IF @c_NSQLDescrip > ''
      BEGIN
         SET @c_SKUImageURL = ''
         
         SELECT @c_SKUImageURL = s.BUSR4
         FROM SKU AS s WITH(NOLOCK)
         WHERE s.StorerKey = @c_Storerkey
         AND s.Sku = @c_SKU
               
         IF @c_SKUImageURL <> ''
         BEGIN
            IF CHARINDEX(@c_NSQLDescrip, @c_SKUImageURL) = 0 
            BEGIN
               SET @c_SKUImageURL = ''
            END
            ELSE 
            BEGIN
               SELECT @c_Storerkey  AS [StorerKey], 
                      @c_SKU        AS [SKU],
                      @c_SKUImageURL AS [ImageURL]             
            END
         END   
      END
      
      IF @c_SKUImageURL = '' 
      BEGIN
         SELECT @c_Storerkey AS [StorerKey], 
                  @c_SKU       AS [SKU],
                  'https://intranetapi.lfuat.net/GenericAPI/GetFile?src=%2BGLq4DAwiIfSKV%2FVqwkCb35eKoWeQCCw' AS [URL]        --(Wan03)
                 -- 'https://intranetapi.lfuat.net/GenericAPI/GetFile?src=IcOC6d%2BAoBNa16e0gLVR7PS6th0bgaLCsPIZ9M4UmX2CNC%2Fz69UrlCEmIguGHETX%2Bo1U7b8omrkl%2Bw9qT75BasN0VsuVylaxFaAgqXjo%2FlpuCd15Vao%2B6xpSHzVX1LVQzEk2HRWABiY%3D' AS [URL]                   
      END   
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END   
   EXIT_SP:
   
   --(Wan01) - START
   IF @n_Continue = 3 
   BEGIN
      SET @b_Success = 0
   END
   
   --REVERT    --(Wan02)
   --(Wan01) - END
END -- procedure

GO
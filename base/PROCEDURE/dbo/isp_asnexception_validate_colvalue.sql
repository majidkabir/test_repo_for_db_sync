SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ASNException_Validate_ColValue                      */
/* Creation Date: 2021-05-10                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-16957 - [CN]Nike_Phoeix_B2C_Exceed_Exception_Tracking  */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2020-05-10  Wan      1.0   Created                                   */
/* 2020-05-31  Wan01    1.1   CR1.5 - Use Script to Block first         */
/* 2021-10-20  Wan02    1.2   WMS-18121-[CN]Nike_Phoeix_B2C_Exceed_     */
/*                            Exception_Tracking-CR                     */
/************************************************************************/
CREATE PROC [dbo].[isp_ASNException_Validate_ColValue]
     @n_RowRef             BIGINT
   , @c_Facility           NVARCHAR(5)  = ''
   , @c_Storerkey          NVARCHAR(15) = ''
   , @c_DocumentNo         NVARCHAR(10) = ''
   , @c_ColName            NVARCHAR(50) = ''
   , @c_ColValue           NVARCHAR(50) = '' 
   , @c_ColName01_RDF      NVARCHAR(50) = ''    OUTPUT
   , @c_ColVal01_RDF       NVARCHAR(50) = ''    OUTPUT   
   , @c_ColName02_RDF      NVARCHAR(50) = ''    OUTPUT
   , @c_ColVal02_RDF       NVARCHAR(50) = ''    OUTPUT   
   , @c_ColName03_RDF      NVARCHAR(50) = ''    OUTPUT
   , @c_ColVal03_RDF       NVARCHAR(50) = ''    OUTPUT  
   , @b_Success            INT          = 1     OUTPUT
   , @n_Err                INT          = 0     OUTPUT
   , @c_ErrMsg             NVARCHAR(255)= ''    OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT = @@TRANCOUNT
         , @n_Continue        INT = 1
         
         , @n_Cnt             INT = 0           --(Wan01) - CR1.5
         , @c_TrackingNo      NVARCHAR(40) = '' --(Wan01) - CR1.5
         
         , @c_UserDefine05    NVARCHAR(30) = '' --(Wan02)
         , @c_PlatForm        NVARCHAR(30) = '' --(Wan02)
         
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_DocumentNo = ISNULL(@c_DocumentNo,'')
   SET @c_ColName = ISNULL(@c_ColName,'')
   SET @c_ColValue= ISNULL(@c_ColValue,'')
   
   IF @c_ColName = ''
   BEGIN
      GOTO QUIT_SP
   END
      
   IF @c_ColName = 'facility' AND @c_ColValue = ''
   BEGIN
      SET @n_Continue = 3 
      SET @n_Err = 88110
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Facility is Required. (isp_ASNException_Validate_ColValue)'
      GOTO QUIT_SP
   END
   
   IF @c_ColName = 'storerkey' AND @c_ColValue = ''
   BEGIN
      SET @n_Continue = 3 
      SET @n_Err = 88120
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Storerkey is Required. (isp_ASNException_Validate_ColValue)'
      GOTO QUIT_SP
   END
   
   IF @c_ColName = 'Userdefine01' --AND @c_ColValue <> ''                                    --(Wan02)
   BEGIN
      --Wan01 - START
      SET @n_Cnt = 0
      SELECT @c_TrackingNo = ISNULL(dst.Userdefine01,'')
            ,@n_Cnt = 1
      FROM dbo.DocStatusTrack AS dst WITH (NOLOCK)
      WHERE DocumentNo = @c_DocumentNo
      
      IF @c_TrackingNo <> '' AND @c_TrackingNo <> @c_ColValue 
      BEGIN
         SET @n_Continue = 3 
         SET @n_Err = 88125
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Not Allow to change Tracking #'
                       + '. (isp_ASNException_Validate_ColValue)'
         GOTO QUIT_SP
      END
     --Wan01 - END
      
      SET @c_ColName01_RDF = 'Userdefine04'
      SET @c_ColVal01_RDF  = 'Y'
      IF NOT EXISTS (SELECT 1 
                     FROM RDT.rdtDataCapture AS rdc WITH (NOLOCK)
                     WHERE rdc.StorerKey = @c_Storerkey
                     AND rdc.Facility = @c_Facility
                     AND rdc.V_String1= @c_ColValue
      )
      BEGIN
         --(Wan02) - START
         SET @n_Continue = 3 
         SET @n_Err = 88126
         SET @c_ErrMsg = 'Invalid Tracking #' + '. (isp_ASNException_Validate_ColValue)'
         SET @c_ColName01_RDF = ''              --SET @c_ColName01_RDF = 'Userdefine04'
         SET @c_ColVal01_RDF  = ''              --SET @c_ColVal01_RDF  = 'N'
         --(Wan02) - END
      END
      
      SET @c_ColName02_RDF = 'Userdefine05'
      
      SELECT TOP 1 @c_ColVal02_RDF = r.CarrierName
      FROM dbo.DocInfo AS di WITH (NOLOCK)
      JOIN dbo.RECEIPT AS r  WITH (NOLOCK) ON di.Key1 = r.ReceiptKey
      WHERE di.TableName = 'RECEIPT'
      AND di.Key3 = @c_ColValue
      ORDER BY di.AddDate DESC
      
      --(Wan02) - START
      IF @c_ColVal02_RDF <> ''
      BEGIN
         SET @c_UserDefine05 = @c_ColVal02_RDF
         GOTO DEFAULT_USERDEFINE08
         RETURN_DEFAULT_USERDEFINE08:
      END
      --(Wan02) - END
   END
   
   IF @c_ColName = 'Userdefine03' 
   BEGIN
      --(Wan02) - START
      IF @c_ColValue = ''
      BEGIN
         SET @n_Continue = 3 
         SET @n_Err = 88129
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Quantity is Required. (isp_ASNException_Validate_ColValue)'
         GOTO QUIT_SP      
      END  
      --(Wan02) - END
      --    
      IF ISNUMERIC(@c_ColValue) = 0
      BEGIN
         SET @n_Continue = 3 
         SET @n_Err = 88130
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Invalid Quantity Type. Only Number is allowed. (isp_ASNException_Validate_ColValue)'
         GOTO QUIT_SP
      END
      
      IF CONVERT(INT, @c_ColValue) <= 0
      BEGIN
         SET @n_Continue = 3 
         SET @n_Err = 88140
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Invalid Quantity. Quantity <= 0. (isp_ASNException_Validate_ColValue)'
         GOTO QUIT_SP
      END
   END

   --(Wan02) - START   
   IF @c_ColName = 'userdefine02' AND @c_ColValue = ''
   BEGIN
      SET @n_Continue = 3 
      SET @n_Err = 88160
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + N': Exp.reason╥∞│ú╘¡╥≥ is Required. (isp_ASNException_Validate_ColValue)'
      GOTO QUIT_SP
   END
   
   IF @c_ColName = 'userdefine05' AND @c_ColValue <> ''
   BEGIN
      SET @c_UserDefine05 = @c_ColValue
      DEFAULT_USERDEFINE08:
      
      SELECT TOP 1 @c_PlatForm = c.UDF04 
      FROM dbo.CODELKUP AS c WITH (NOLOCK) WHERE c.ListName = 'NKEXC' AND LEFT(@c_UserDefine05,c.UDF02) = c.UDF01
      ORDER BY c.Code
      
      IF @c_PlatForm <> ''
      BEGIN
         IF @c_ColName = 'userdefine05'
         BEGIN
            SET @c_ColName01_RDF = 'userdefine08' 
            SET @c_ColVal01_RDF  = @c_PlatForm  
         END
         ELSE
         BEGIN
            SET @c_ColName03_RDF = 'userdefine08'
            SET @c_ColVal03_RDF  = @c_PlatForm  
            GOTO RETURN_DEFAULT_USERDEFINE08             
         END
      END
   END
   
   IF @c_ColName = 'userdefine08' AND  @c_ColValue = ''
   BEGIN
      SET @n_Continue = 3 
      SET @n_Err = 88170
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Platform is Required. (isp_ASNException_Validate_ColValue)'
      GOTO QUIT_SP
   END
   --(Wan01) - END
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ASNException_Validate_ColValue'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO
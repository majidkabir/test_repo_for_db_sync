SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_EPACKPrePrintCheck_Wrapper                          */
/* Creation Date: 13-JUL-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-2306 - CN-Nike SDC WMS ECOM Packing CR                  */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2018-10-25  Wan01    1.1   PACKLIST Force To Print to QSPooler       */
/************************************************************************/
CREATE PROC [dbo].[isp_EPACKPrePrintCheck_Wrapper]
           @c_PickSlipNo      NVARCHAR(10)
         , @c_CartonNoStart   NVARCHAR(10)
         , @c_CartonNoEnd     NVARCHAR(10)
         , @c_ReportType      NVARCHAR(30)
         , @b_Success         INT            OUTPUT
         , @n_Err             INT            OUTPUT
         , @c_ErrMsg          NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_SQL             NVARCHAR(4000) 
         , @c_SQLArgument     NVARCHAR(4000) 

         , @c_Orderkey        NVARCHAR(10)
         , @c_Facility        NVARCHAR(5)
         , @c_Storerkey       NVARCHAR(15)

         , @c_SPCode          NVARCHAR(30)
         , @c_ReportTypes     NVARCHAR(50)

         , @c_DirectPrint     NVARCHAR(30)   --(Wan01)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   WHILE @@TRANCOUNT > 0
   BEGIN 
      COMMIT TRAN
   END

   SET @c_Orderkey = ''
   SET @c_Storerkey= ''
   SELECT @c_Orderkey = ISNULL(RTRIM(PH.Orderkey),'')
         ,@c_Storerkey= PH.Storerkey
   FROM PACKHEADER PH WITH (NOLOCK)
   WHERE PH.PickSlipNo = @c_PickSlipNo

   IF @c_Orderkey = ''
   BEGIN
      GOTO QUIT_SP
   END

   SET @c_Facility = ''
   SELECT @c_Facility = OH.Facility
   FROM ORDERS OH WITH (NOLOCK)
   WHERE OH.Orderkey = @c_Orderkey

   --(Wan01) - START
   IF @c_ReportType = 'PACKLIST'
   BEGIN
      SET @b_Success = 1
      SET @c_DirectPrint = ''
      EXEC nspGetRight      
            @c_Facility  = @c_Facility     
         ,  @c_StorerKey = @c_StorerKey      
         ,  @c_sku       = NULL      
         ,  @c_ConfigKey = 'EPACKAllowDirectPrn'      
         ,  @b_Success   = @b_Success       OUTPUT      
         ,  @c_authority = @c_DirectPrint   OUTPUT      
         ,  @n_err       = @n_err           OUTPUT      
         ,  @c_errmsg    = @c_errmsg        OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 61010
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                     + ': Error Executing nspGetRight - EPACKAllowDirectPrint. (isp_EPACKPrePrintCheck_Wrapper)'  
         GOTO QUIT_SP
      END

      IF @c_DirectPrint <> '1'
      BEGIN 
         IF NOT EXISTS (SELECT 1
                        FROM RDT.RDTREPORT RPT WITH (NOLOCK)
                        WHERE RPT.Storerkey = @c_Storerkey
                        AND   RPT.ReportType= @c_ReportType
                        AND   RPT.Function_ID= '999'
                        AND   (DataWindow <> '' AND DataWindow IS NOT NULL) 
                        )
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 61020
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                        + ': ECOM PackList is not setup to print to QSpooler. Please Check. (isp_EPACKPrePrintCheck_Wrapper)'  
            GOTO QUIT_SP         
         END
      END
   END
   --(Wan01) - END

   SET @b_Success = 1
   SET @c_SPCode = ''
   EXEC nspGetRight      
         @c_Facility  = @c_Facility     
      ,  @c_StorerKey = @c_StorerKey      
      ,  @c_sku       = NULL      
      ,  @c_ConfigKey = 'EPACKPrePrintCheck_SP'      
      ,  @b_Success   = @b_Success  OUTPUT      
      ,  @c_authority = @c_SPCode   OUTPUT      
      ,  @n_err       = @n_err      OUTPUT      
      ,  @c_errmsg    = @c_errmsg   OUTPUT
      ,  @c_Option1   = @c_ReportTypes OUTPUT

   IF @b_Success <> 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 61030
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                  + ': Error Executing nspGetRight. (isp_EPACKPrePrintCheck_Wrapper)'  
      GOTO QUIT_SP
   END

   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN 
      GOTO QUIT_SP
   END    

   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
      GOTO QUIT_SP
   END

   IF @c_ReportTypes <> ''
   BEGIN
      IF NOT EXISTS (SELECT 1    
                     FROM dbo.fnc_DelimSplit(',',@c_ReportTypes) 
                     WHERE ColValue = @c_ReportType   
                     )
      BEGIN
         GOTO QUIT_SP
      END 
   END

   SET @c_SQL = N'EXEC ' + @c_SPCode 
              + ' @c_PickSlipNo    = @c_PickSlipNo'
              + ',@c_CartonNoStart = @c_CartonNoStart'
              + ',@c_CartonNoEnd   = @c_CartonNoEnd'
              + ',@c_ReportType    = @c_ReportType'
              + ',@b_Success       = @b_Success OUTPUT'
              + ',@n_Err           = @n_Err     OUTPUT'
              + ',@c_ErrMsg        = @c_ErrMsg  OUTPUT'

   SET @c_SQLArgument= N'@c_PickSlipNo    NVARCHAR(10)'
                     + ',@c_CartonNoStart NVARCHAR(10)'
                     + ',@c_CartonNoEnd   NVARCHAR(10)'
                     + ',@c_ReportType    NVARCHAR(30)'
                     + ',@b_Success       INT            OUTPUT'
                     + ',@n_Err           INT            OUTPUT'
                     + ',@c_ErrMsg        NVARCHAR(255)  OUTPUT'

   EXEC sp_ExecuteSql @c_SQL 
         , @c_SQLArgument
         , @c_PickSlipNo      
         , @c_CartonNoStart   
         , @c_CartonNoEnd      
         , @c_ReportType 
         , @b_Success   OUTPUT
         , @n_Err       OUTPUT
         , @c_ErrMsg    OUTPUT      
        
   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      IF @c_ErrMsg = ''
      BEGIN
         SET @n_Err = 61040
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                     + ': Error Executing ' + RTRIM(@c_SPCode)+ '. (isp_EPACKPrePrintCheck_Wrapper)'  
      END
      GOTO QUIT_SP
   END

   SET @n_Continue = @b_Success -- @b_Success (1 = print, 2 = not to print, no errmsg) 

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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_EPACKPrePrintCheck_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = @n_Continue
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN 
      BEGIN TRAN
   END
END -- procedure

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispPKBT13                                          */
/* Creation Date: 13-Jan-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21500 - [TW] Exceed Packing Module Auto Print CR        */
/*                                                                      */
/* Called By: isp_Packing_Bartender_Print                               */
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 13-Jan-2022 WLChooi  1.0   DevOps Combine Script                     */
/* 03-Mar-2023 WLChooi  1.1   WMS-21500 - Bug Fix (WL01)                */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispPKBT13]
   @c_printerid  NVARCHAR(50) = '',  
   @c_labeltype  NVARCHAR(30) = '',  
   @c_userid     NVARCHAR(100) = '',  
   @c_Parm01     NVARCHAR(60) = '', --Pickslipno         
   @c_Parm02     NVARCHAR(60) = '', --carton from         
   @c_Parm03     NVARCHAR(60) = '', --carton to         
   @c_Parm04     NVARCHAR(60) = '',          
   @c_Parm05     NVARCHAR(60) = '',          
   @c_Parm06     NVARCHAR(60) = '',          
   @c_Parm07     NVARCHAR(60) = '',          
   @c_Parm08     NVARCHAR(60) = '',          
   @c_Parm09     NVARCHAR(60) = '',          
   @c_Parm10     NVARCHAR(60) = '',    
   @c_Storerkey  NVARCHAR(15) = '',
   @c_NoOfCopy   NVARCHAR(5) = '1',
   @c_Subtype    NVARCHAR(20) = '',
   @b_Success    INT      OUTPUT,
   @n_Err        INT      OUTPUT, 
   @c_ErrMsg     NVARCHAR(250) OUTPUT   
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_continue           INT 
         , @c_Pickslipno         NVARCHAR(10) = ''
         , @c_Facility           NVARCHAR(5)  = ''
         , @c_CartonNoStart      NVARCHAR(10)
         , @c_CartonNoEnd        NVARCHAR(10)
         , @c_PHStatus           NVARCHAR(10)
                                                      
   SET @n_err = 0
   SET @b_success = 1
   SET @c_errmsg = ''
   SET @n_continue = 1
   
   SET @c_Pickslipno    = @c_Parm01
   SET @c_CartonNoStart = @c_Parm02
   SET @c_CartonNoEnd   = @c_Parm03

   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT @c_PHStatus = PACKHEADER.[Status] 
      FROM PACKHEADER (NOLOCK)
      WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo 

      IF @c_Subtype = 'UCCLABEL' AND @c_PHStatus < '9'
         GOTO QUIT_SP
   END
   
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      EXEC isp_BT_GenBartenderCommand   	  
              @cPrinterID = @c_PrinterID
           ,  @c_LabelType = @c_LabelType
           ,  @c_userid = @c_UserId
           ,  @c_Parm01 = @c_Parm01 --pickslipno
           ,  @c_Parm02 = '1' --carton from   --WL01
           ,  @c_Parm03 = '99999' --carton to   --WL01
           ,  @c_Parm04 = @c_Parm04
           ,  @c_Parm05 = @c_Parm05
           ,  @c_Parm06 = @c_Parm06
           ,  @c_Parm07 = @c_Parm07
           ,  @c_Parm08 = @c_Parm08
           ,  @c_Parm09 = @c_Parm09
           ,  @c_Parm10 = @c_Parm10
           ,  @c_Storerkey = @c_Storerkey
           ,  @c_NoCopy = @c_NoOfCopy
           ,  @c_Returnresult = 'N' 
           ,  @n_err = @n_Err OUTPUT
           ,  @c_errmsg = @c_ErrMsg OUTPUT   	
                               
      IF @n_Err <> 0 
      BEGIN
         SET @n_continue = 3
      END
      
      SET @b_success = 1   --Do not continue print datawindow
   END     
   
QUIT_SP:
   IF @n_continue = 3
   BEGIN
      SET @b_success = 0
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPKBT13'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO
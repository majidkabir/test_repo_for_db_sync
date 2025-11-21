SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispPKBT06                                                   */
/* Creation Date: 10-Jun-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-17206 - Print Bartender Based on Ordergroup and DocType */
/*                                                                      */
/* Called By: isp_Packing_Bartender_Print                               */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPKBT06]
   @c_printerid  NVARCHAR(50) = '',  
   @c_labeltype  NVARCHAR(30) = '',  
   @c_userid     NVARCHAR(18) = '',  
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
      
   DECLARE @n_continue        INT 
         , @c_Pickslipno      NVARCHAR(10) = ''
         , @c_Orderkey        NVARCHAR(10) = ''
         , @c_DocType         NVARCHAR(10) = ''
         , @c_OrderGroup      NVARCHAR(20) = ''
         , @c_OIFPlatform     NVARCHAR(20) = ''
                                                      
   SET @n_err = 0
   SET @b_success = 1
   SET @c_errmsg = ''
   SET @n_continue = 1
   
   SET @c_Pickslipno = @c_Parm01

   SELECT @c_OrderKey    = ORDERS.OrderKey 
        , @c_OrderGroup  = ORDERS.OrderGroup
        , @c_DocType     = ORDERS.Doctype
        , @c_OIFPlatform = ORDERINFO.[Platform]
   FROM PACKHEADER (NOLOCK)
   JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey
   LEFT JOIN ORDERINFO (NOLOCK) ON OrderInfo.OrderKey = ORDERS.OrderKey
   WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo 
   
   --Consider Conso
   IF ISNULL(@c_OrderKey,'') = ''
   BEGIN
      SELECT @c_OrderKey    = ORDERS.OrderKey 
           , @c_OrderGroup  = ORDERS.OrderGroup
           , @c_DocType     = ORDERS.Doctype
           , @c_OIFPlatform = ORDERINFO.[Platform]
      FROM PACKHEADER (NOLOCK)
      JOIN LOADPLANDETAIL (NOLOCK) ON LOADPLANDETAIL.Loadkey = PACKHEADER.Loadkey
      JOIN ORDERS (NOLOCK) ON LOADPLANDETAIL.Orderkey = ORDERS.Orderkey
      LEFT JOIN ORDERINFO (NOLOCK) ON OrderInfo.OrderKey = ORDERS.OrderKey
      WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo
   END
   
   IF LTRIM(RTRIM(@c_OrderGroup)) = 'aCommerce'
   BEGIN
      IF @c_DocType = 'E'
      BEGIN
         IF EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK) 
                    WHERE CL.LISTNAME = 'ACOM-IDLBL' 
                    AND CL.Storerkey = @c_Storerkey
                    AND CL.Code = @c_OIFPlatform
                    AND CL.Short = '1')
         BEGIN
            EXEC isp_BT_GenBartenderCommand   	  
                     @cPrinterID = @c_PrinterID
                  ,  @c_LabelType = @c_LabelType
                  ,  @c_userid = @c_UserId
                  ,  @c_Parm01 = @c_Parm01 --pickslipno
                  ,  @c_Parm02 = @c_Parm02 --carton from
                  ,  @c_Parm03 = @c_Parm03 --carton to
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
            END                    --@n_Err <> 0       
         END                       --Exists Codelkup

         SET @b_success = 2        --PrintCartonLabelByITF
      END                          --DocType = 'E'
      ELSE                         
      BEGIN                        --DocType <> 'E'
         EXEC isp_BT_GenBartenderCommand   	  
                  @cPrinterID = @c_PrinterID
               ,  @c_LabelType = @c_LabelType
               ,  @c_userid = @c_UserId
               ,  @c_Parm01 = @c_Parm01 --pickslipno
               ,  @c_Parm02 = @c_Parm02 --carton from
               ,  @c_Parm03 = @c_Parm03 --carton to
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
         END                       --@n_Err <> 0       
      END                          --DocType <> 'E'
   END                             --OrderGroup
   ELSE                            --OrderGroup <> 'aCommerce'
   BEGIN
      --Print PDF (PACKUCC2PDF)
      --PDF Should be printed before Bartender
      SET @b_success = 1
   END
                     
QUIT_SP:
   IF @n_continue = 3
   BEGIN
      SET @b_success = 0
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPKBT06'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispCTNLBLITF03                                     */
/* Creation Date: 21-Jun-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-17206 - RG - aCommerce Adidas - EXCEED Packing UCCLabel */
/*                                                                      */
/* Called By: isp_PrintCartonLabel_Interface                            */
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 03-Nov-2021  WLChooi 1.0   DevOps Combine Script                     */
/* 20-Apr-2022  WLChooi 1.1   WMS-19490 - Modify Logic (WL01)           */
/************************************************************************/
CREATE PROCEDURE [dbo].[ispCTNLBLITF03]
      @c_Pickslipno   NVARCHAR(10)     
  ,   @n_CartonNo_Min INT 
  ,   @n_CartonNo_Max INT 
  ,   @b_Success      INT           OUTPUT  
  ,   @n_Err          INT           OUTPUT  
  ,   @c_ErrMsg       NVARCHAR(255) OUTPUT
   
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_continue        INT
         , @n_starttcnt       INT
         , @n_SUMPackQty      INT = 0
         , @n_SUMPickQty      INT = 0
         , @c_Orderkey        NVARCHAR(10)
         , @c_ECOM_S_Flag     NVARCHAR(1)
         , @c_Storerkey       NVARCHAR(15)
   
   DECLARE @c_PrintCartonLabelByITF   NVARCHAR(100)
         , @c_Option1                 NVARCHAR(255)
         , @c_Option2                 NVARCHAR(255)
         , @c_Option3                 NVARCHAR(255)
         , @c_BuyerPO                 NVARCHAR(50)   --WL01
                                                                                               
   SET @n_err = 0
   SET @b_success = 1
   SET @c_errmsg = ''
   SET @n_continue = 1
   SET @n_starttcnt = @@TRANCOUNT

   SELECT @n_SUMPackQty = SUM(PACKDETAIL.Qty)
   FROM PACKDETAIL (NOLOCK)
   WHERE PACKDETAIL.PickSlipNo = @c_Pickslipno

   SELECT @n_SUMPickQty = SUM(PD.Qty)
        , @c_Orderkey   = MAX(PH.Orderkey)
   FROM PACKHEADER PH (NOLOCK)
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = PH.Orderkey
   WHERE PH.PickSlipNo = @c_Pickslipno

   IF ISNULL(@n_SUMPackQty, 0) = 0
      SET @n_SUMPackQty = 0

   IF ISNULL(@n_SUMPickQty, 0) = 0
      SET @n_SUMPickQty = 0

   SELECT @c_ECOM_S_Flag = OH.ECOM_SINGLE_Flag
        , @c_Storerkey   = OH.StorerKey
        , @c_BuyerPO     = OH.BuyerPO   --WL01
   FROM ORDERS OH (NOLOCK)
   WHERE OH.OrderKey = @c_Orderkey

   EXEC nspGetRight 
      '',  
      @c_StorerKey,              
      '',                    
      'PrintCartonLabelByITF', 
      @b_success               OUTPUT,
      @c_PrintCartonLabelByITF OUTPUT,
      @n_err                   OUTPUT,
      @c_errmsg                OUTPUT,
      @c_Option1               OUTPUT,
      @c_Option2               OUTPUT,
      @c_Option3               OUTPUT
   
   --For Single Order, due to PB print label before updating Packheader.Status to '9' for Single Order Pack Confirm
   --So in this stage, Status < '9' for Single Order
   --Skip insert Transmitlog2 in isp_PrintCartonLabel_Interface
   IF EXISTS (SELECT 1   
              FROM PACKHEADER (NOLOCK)
              WHERE PickSlipNo = @c_Pickslipno AND [Status] < '9' ) AND @c_ECOM_S_Flag = 'S'
   BEGIN  
      SET @n_continue = 1      
      SET @c_errmsg = ''   
   END
   --WL01 S
   ELSE IF EXISTS (SELECT 1   
              FROM PACKHEADER (NOLOCK)
              WHERE PickSlipNo = @c_Pickslipno AND [Status] < '9' ) AND @c_BuyerPO LIKE '%LOAN%'   
   BEGIN  
      SET @n_continue = 1      
      SET @c_errmsg = ''   
   END
   --WL01 E
   --Only proceed insert Transmitlog2 in isp_PrintCartonLabel_Interface if already pack confirmed (Status = 9) (Multi-Order)
   --Call from PostPackConfirmSP, for single order, already pack confirmed and Packinfo.Weight & Cube are updated, proceed to trigger EDI
   ELSE IF EXISTS (SELECT 1   
                   FROM PACKHEADER (NOLOCK)
                   WHERE PickSlipNo = @c_Pickslipno AND [Status] = '9' )  
   BEGIN  
      SET @n_continue = 1      
      SET @c_errmsg = 'CONTINUE'    
   END
   ELSE
   BEGIN
      SET @n_continue = 1      
      SET @c_errmsg = ''
   END    
   
   --If reprint - Transmitlog2 already existed, skip generate transmitlog2 record again)                             
   IF EXISTS (SELECT 1 
              FROM TRANSMITLOG2 T2 (NOLOCK) 
              WHERE T2.tablename = @c_Option1
              AND T2.key3 = @c_Storerkey
              AND T2.key1 = @c_Pickslipno)
   BEGIN
      SET @n_continue = 1      
      SET @c_errmsg = ''  
   END        

QUIT_SP:
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0     
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt 
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ispCTNLBLITF03"
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
END  

GO
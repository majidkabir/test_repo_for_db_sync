SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPAKCF18                                            */
/* Creation Date: 03-Nov-2021                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-18248 - SG Adidas Update Packdetail & Packinfo upon Pack   */ 
/*                      Confirm                                            */
/*                                                                         */
/* Called By: PostPackConfirmSP                                            */
/*                                                                         */
/* GitLab Version: 1.1                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 03-Nov-2021  WLChooi 1.0   DevOps Combine Script                        */
/* 20-Apr-2022  WLChooi 1.1   WMS-19490 - Merged with ispPAKCF16 (WL01)    */
/***************************************************************************/  
CREATE PROC [dbo].[ispPAKCF18]  
(     @c_PickSlipNo  NVARCHAR(10)   
  ,   @c_Storerkey   NVARCHAR(15)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug           INT = 0
         , @n_Continue        INT 
         , @n_StartTCnt       INT 
 
   DECLARE @c_ECOM_S_Flag     NVARCHAR(1)
         , @c_OrderType       NVARCHAR(20)
         , @c_DocType         NVARCHAR(20)
         , @c_Orderkey        NVARCHAR(10)
         , @n_CartonNo        INT
         , @c_TrackingNo      NVARCHAR(50)
         , @c_UDF05           NVARCHAR(50)

   --WL01 S
   DECLARE @n_Weight          DECIMAL(20, 5)
         , @n_Cube            DECIMAL(20, 5)
         , @n_MaxCarton       INT
         , @c_BuyerPO         NVARCHAR(50)
         , @c_OrderGroup      NVARCHAR(50)
   --WL01 E
   
   IF @n_Err > 0
   BEGIN
      SET @b_Debug  = @n_Err
   END

   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  

   IF @@TRANCOUNT = 0
      BEGIN TRAN 

   SELECT @c_ECOM_S_Flag = MAX(OH.ECOM_SINGLE_Flag)
        , @c_OrderType   = MAX(OH.[Type]) 
        , @c_DocType     = MAX(OH.DocType)
        , @c_Orderkey    = MAX(OH.OrderKey)
        , @c_TrackingNo  = MAX(OH.TrackingNo)
        , @n_MaxCarton   = MAX(PD.CartonNo)   --WL01
        , @c_BuyerPO     = MAX(OH.BuyerPO)    --WL01
        , @c_OrderGroup  = MAX(OH.OrderGroup) --WL01
   FROM ORDERS OH (NOLOCK)
   JOIN PACKHEADER PH (NOLOCK) ON OH.OrderKey = PH.Orderkey
   JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo   --WL01
   WHERE PH.PickSlipNo = @c_Pickslipno
   
   --WL01 S
   DECLARE cur_PACKINFO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PIF.CartonNo
   FROM PACKINFO PIF (NOLOCK)
   WHERE PIF.PickSlipNo = @c_PickSlipNo
   AND ISNULL(PIF.[Weight], 0) = 0.00
   AND ISNULL(PIF.[Cube]  , 0) = 0.00
   ORDER BY PIF.CartonNo
   
   OPEN cur_PACKINFO  
          
   FETCH NEXT FROM cur_PACKINFO INTO @n_CartonNo
          
   WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
   BEGIN     	      	   	
      SELECT @n_Cube   = CASE WHEN ISNULL(CZ.[Cube],0) = 0 THEN SUM(PACKDETAIL.Qty * Sku.StdCube) ELSE ISNULL(CZ.[Cube],0) END 
           , @n_Weight = SUM(PACKDETAIL.Qty * Sku.StdGrossWgt) + ISNULL(CZ.CartonWeight,0)  
      FROM PACKDETAIL (NOLOCK)  
      JOIN STORER (NOLOCK) ON (PACKDETAIL.StorerKey = STORER.StorerKey)  
      JOIN SKU (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.SKU = SKU.Sku)  
      --LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (STORER.CartonGroup = CZ.CartonizationGroup AND CZ.UseSequence = 1)   --WL01
      JOIN PACKINFO (NOLOCK) ON (PACKINFO.Pickslipno = PACKDETAIL.Pickslipno AND PACKINFO.CartonNo = PACKDETAIL.CartonNo)   --WL01
      LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (CZ.CartonType = PACKINFO.CartonType)   --WL01
      WHERE PACKDETAIL.PickSlipNo = @c_Pickslipno  
      AND PACKDETAIL.CartonNo = @n_CartonNo
      GROUP BY ISNULL(CZ.[Cube],0), ISNULL(CZ.CartonWeight,0)     
      
      IF @b_Debug = 1
      BEGIN
         PRINT   '@c_PickSlipNo = ' + RTRIM(@c_PickSlipNo)          + CHAR(13) + 
                 '@n_CartonNo = '   + CAST(@n_CartonNo AS NVARCHAR) + CHAR(13) + 
                 '@n_Weight = '     + CAST(@n_Weight AS NVARCHAR)   + CHAR(13) + 
                 '@n_Cube = '       + CAST(@n_Cube AS NVARCHAR)     + CHAR(13)
      END 	  
      
      UPDATE PACKINFO WITH (ROWLOCK)
      SET [Weight] = @n_Weight 
        , [Cube]   = @n_Cube
      WHERE PACKINFO.PickSlipNo = @c_PickSlipNo
      AND PACKINFO.CartonNo = @n_CartonNo

      SELECT @n_Err = @@ERROR  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 62070     
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update PackInfo table FAILED. (ispPAKCF18)'     
                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
         GOTO QUIT_SP    
      END   
   	 
      FETCH NEXT FROM cur_PACKINFO INTO @n_CartonNo
   END
   CLOSE cur_PACKINFO
   DEALLOCATE cur_PACKINFO
   --WL01 E

   IF @c_DocType = 'E' AND @c_OrderGroup <> 'aCommerce'   --WL01
   BEGIN
      SELECT @c_UDF05 = ISNULL(CL.UDF05,'') 
      FROM ORDERS OH (NOLOCK)
      JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'COURIERLBL'
                               AND CL.Storerkey  = OH.Storerkey
                               AND CL.Code = OH.Salesman
      WHERE OH.Orderkey = @c_Orderkey

      IF @c_UDF05 <> 'Y'
      BEGIN
         DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT CAST(PD.CartonNo AS INT)
         FROM PACKDETAIL PD (NOLOCK)
         WHERE PD.PickSlipNo = @c_PickSlipNo
         ORDER BY CAST(PD.CartonNo AS INT)

         OPEN CUR_LOOP

         FETCH NEXT FROM CUR_LOOP INTO @n_CartonNo

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE PACKDETAIL 
            SET RefNo = @c_TrackingNo
            WHERE PickSlipNo = @c_PickSlipNo
            AND CartonNo = @n_CartonNo

            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3    
               SET @n_err = 62075     
               SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update PACKDETAIL table FAILED. (ispPAKCF18)'     
                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
               GOTO QUIT_SP    
            END  

            UPDATE PACKINFO 
            SET TrackingNo = @c_TrackingNo
            WHERE PickSlipNo = @c_PickSlipNo
            AND CartonNo = @n_CartonNo

            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3    
               SET @n_err = 62080     
               SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update PACKINFO table FAILED. (ispPAKCF18)'     
                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
               GOTO QUIT_SP    
            END 

            FETCH NEXT FROM CUR_LOOP INTO @n_CartonNo
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP
      END
   END

   --WL01 S
   --Trigger EDI when Packinfo updated
   --OR Trigger EDI for Orders.Type = 'RETURN' since not able to trigger EDI during ue_printcartonlabel_interface due to Orders.Type not matched
   IF (@c_ECOM_S_Flag = 'S' OR @c_OrderType = 'RETURN' OR @c_BuyerPO LIKE '%LOAN%') AND @c_OrderGroup = 'aCommerce'   --WL01
   BEGIN
      EXEC [dbo].[isp_PrintCartonLabel_Interface]    
             @c_Pickslipno   = @c_PickSlipNo       
         ,   @n_CartonNo_Min = @n_MaxCarton  
         ,   @n_CartonNo_Max = @n_MaxCarton  
         ,   @b_Success      = @b_Success OUTPUT  
         ,   @n_Err          = @n_Err     OUTPUT  
         ,   @c_ErrMsg       = @c_ErrMsg  OUTPUT 

      IF @n_Err <> 0  
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 62085     
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': EXEC isp_PrintCartonLabel_Interface FAILED. (ispPAKCF18)'     
                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
         GOTO QUIT_SP    
      END 
   END 
   --WL01 E

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END
   
   --WL01 S
   IF CURSOR_STATUS('LOCAL', 'cur_PACKINFO') IN (0 , 1)
   BEGIN
      CLOSE cur_PACKINFO
      DEALLOCATE cur_PACKINFO   
   END
   --WL01 E

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF18'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END 
      RETURN
   END 
END

GO
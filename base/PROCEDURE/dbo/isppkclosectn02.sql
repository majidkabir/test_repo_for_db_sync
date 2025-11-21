SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispPkCloseCTN02                                     */  
/* Creation Date: 27-Jan-2021                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: WMS-16079 - RG - LEGO - EXCEED Packing                       */
/*                                                                       */  
/* Called By: Packing (isp_packautoclosecarton_wrapper)                  */  
/*            storerconfig: PackAutoCloseCarton_SP                       */
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */  
/* 27-Jan-2021 Wan01    1.0   Created.                                   */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispPkCloseCTN02]      
      @c_PickSlipNo  NVARCHAR(10)
   ,  @c_Storerkey   NVARCHAR(15) 
   ,  @c_ScanSkuCode NVARCHAR(50)
   ,  @c_Sku         NVARCHAR(20)  
   ,  @c_CloseCarton NVARCHAR(10)         OUTPUT
   ,  @b_Success     INT            = 1   OUTPUT
   ,  @n_Err         INT            = 0   OUTPUT
   ,  @c_ErrMsg      NVARCHAR(250)  = ''  OUTPUT
   ,  @n_CartonNo    INT            = 0
   ,  @c_ScanColumn  NVARCHAR(50)   = ''  
   ,  @n_Qty         INT            = 0                 
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Continue     INT = 1 
         , @n_starttcnt    INT = @@TRANCOUNT        
         , @n_debug        INT = 0
         , @n_PackItemCnt  INT = 0
         , @n_QtyPacked    INT = 0
         
         , @n_CaseCnt      INT = 0
         
         , @c_UPCCode      NVARCHAR(30) = ''
         , @c_PackedSku    NVARCHAR(20) = ''
         , @c_PackedUPC    NVARCHAR(20) = ''
                
   SET @b_success=0
   SET @n_err=0
   SET @c_errmsg=''

   SET @c_CloseCarton = 'N'

   --EXEC dbo.ispSKUDC06
   --     @c_Storerkey = @c_Storerkey    
   --   , @c_Sku       = @c_ScanSkuCode          
   --   , @c_NewSku    = @c_UPCCode      OUTPUT   --SKU
   --   , @b_Success   = @b_Success      OUTPUT
   --   , @n_Err       = @n_Err          OUTPUT 
   --   , @c_ErrMsg    = @c_ErrMsg       OUTPUT
      
   --IF @b_Success = 0
   --BEGIN
   --   SET @n_Continue = 3
   --   SET @n_Err = 67010
   --   SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing ispSKUDC06. (ispPkCloseCTN02)'
   --   GOTO QUIT_SP
   --END
   
   IF @n_CartonNo > 0 
   BEGIN
      SELECT @n_PackItemCnt = COUNT( DISTINCT pd.sku )
            ,@c_PackedSku   = MIN(pd.sku)
            ,@n_QtyPacked   = SUM(pd.Qty)
      FROM PACKDETAIL AS pd WITH (NOLOCK)
      WHERE pd.PickSlipNo = @c_PickSlipNo
      AND pd.CartonNo = @n_CartonNo
      GROUP BY pd.PickSlipNo
            ,  pd.CartonNo
 
      IF @n_PackItemCnt = 1
      BEGIN
         SELECT @c_PackedUPC = UPC.UPC  FROM UPC (NOLOCK)
         JOIN PACK AS p WITH (NOLOCK) ON p.PackKey = UPC.PackKey
         WHERE UPC.StorerKey = @c_Storerkey AND UPC.Sku = @c_PackedSku
         AND   UPC.UOM = p.PackUOM1 
         AND   p.CaseCnt = @n_QtyPacked

         IF LEN(RTRIM(@c_PackedUPC)) >= 14  -- Current Carton is a Full Carton Box
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 67020
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Cannot Pack item Into a Full Carton. (ispPkCloseCTN02)'
            GOTO QUIT_SP
         END
      END
      ELSE
      BEGIN
         IF EXISTS(  SELECT 1 FROM UPC (NOLOCK)
                     JOIN PACK AS p WITH (NOLOCK) ON p.PackKey = UPC.PackKey
                     WHERE UPC.StorerKey = @c_Storerkey AND UPC.Sku = @c_Sku
                     AND   UPC.UOM = p.PackUOM1
                     AND   p.CaseCnt = @n_Qty
                      )
         BEGIN
            IF @n_PackItemCnt > 0      -- If Current CartonNo Already has packed item with Item and Try to pack a full carton item again
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 67030
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Cannot Mix Full Carton with Loose Sku. (ispPkCloseCTN02)'
               GOTO QUIT_SP
            END
            SET @c_CloseCarton = 'Y'
         END
      END
   END
               
 QUIT_SP:
    
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
      execute nsp_logerror @n_err, @c_errmsg, "ispPkCloseCTN02"  
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
END --sp end

GO
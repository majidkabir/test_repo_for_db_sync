SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: isp_packfindsingleorder                               */  
/* Creation Date: 25-MAY-2016                                              */  
/* Copyright: LFL                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: SOS#370148 - SG - Nike Ecom Packing. Find single order by      */                                 
/*          drop id                                                        */
/*                                                                         */  
/* Called By:                                                              */  
/*                                                                         */  
/*                                                                         */  
/* PVCS Version: 1.1                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date        Ver  Author   Purposes                                      */  
/* 09-JAN-2018 1.1  Wan01    Increase @c_Dropid to NVARCHAR(20)            */ 
/* 27-Nov-2020 1.2  NJOW01   WMS-15762 filter out orders.status 9 AND Sort */
/*                           by order.status < 5.                          */
/* 08-Jun-2021 1.3  NJOW02   WMS-17104 exclude sostatus by codelkup        */ 
/***************************************************************************/    
CREATE PROC [dbo].[isp_packfindsingleorder]    
(     @c_DropId      NVARCHAR(20)     
  ,   @c_Storerkey   NVARCHAR(15) 
  ,   @c_Sku         NVARCHAR(20) 
  ,   @c_Orderkey    NVARCHAR(10)  OUTPUT
  ,   @c_PickslipNo  NVARCHAR(10)  OUTPUT
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
    
   DECLARE @b_Debug              INT  
         , @n_Continue           INT   
         , @n_StartTCount        INT   
   
   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''  
 
   SET @b_Debug  = 1
   SET @n_Continue = 1    
   SET @n_StartTCount = @@TRANCOUNT  
   SET @c_Orderkey = ''  
   SET @c_PickSlipNo = ''
       
   SELECT TOP 1 @c_Orderkey = PD.Orderkey
   FROM PICKDETAIL PD (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON PD.Orderkey = O.Orderkey
   LEFT JOIN PACKHEADER PH (NOLOCK) ON O.Orderkey = PH.Orderkey   
   LEFT JOIN PACKDETAIL PKD (NOLOCK) ON PH.PickSlipNo = PKD.PickSlipNo   
   WHERE PD.DropID = @c_DropID
   AND ISNULL(PD.Dropid,'') <> ''
   AND PD.Storerkey = @c_Storerkey
   AND PD.SKU = @c_Sku
   AND PKD.Pickslipno IS NULL
   AND O.Status <> '9'  --NJOW02
   AND O.SOStatus NOT IN (SELECT Code
                          FROM CODELKUP (NOLOCK) 
                          WHERE Listname = 'NONEPACKSO'
                          --AND Code NOT IN ('CANC', 'HOLD')
                          AND (Storerkey = O.Storerkey OR ISNULL(Storerkey,'')='')) --NJOW03
   GROUP BY PD.Orderkey, O.Priority, O.Status  --NJOW01
   HAVING SUM(PD.QTY) = 1
   ORDER BY CASE WHEN O.Status < '5' THEN 1 ELSE 2 END, O.Priority, PD.Orderkey  --NJOW02   
   --ORDER BY O.Priority, PD.Orderkey

   IF ISNULL(@c_Orderkey,'') =  ''  
   BEGIN
      SET @n_Continue = 3
      SET @n_err      = 83005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': No Non-Pack Single Order Found from Drop ID ''' + RTRIM(ISNULL(@c_DropId,'')) + ''' (isp_packfindsingleorder)'
      GOTO QUIT_SP
   END
   ELSE
   BEGIN
      SELECT TOP 1 @c_PickSlipNo = Pickheaderkey
      FROM PICKHEADER(NOLOCK)
      WHERE Orderkey = @c_Orderkey   
   END
        
   QUIT_SP:  
  
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCount  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      Execute nsp_logerror @n_err, @c_errmsg, 'isp_packfindsingleorder'  
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         COMMIT TRAN  
      END   
  
      RETURN  
   END   
END 

GO
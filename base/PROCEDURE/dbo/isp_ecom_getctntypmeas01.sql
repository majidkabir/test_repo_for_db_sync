SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_Ecom_GetCTNTypMeas01                                    */
/* Creation Date: 24-APR-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by:   Wan                                                    */
/*                                                                      */
/* Purpose: WMS-4628 - [CR] DYSON - ECOM Packing                        */
/*        :                                                             */
/* Called By:  isp_Ecom_GetPackCartonType                               */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_Ecom_GetCTNTypMeas01]
         @c_CartonGroup NVARCHAR(10) 
      ,  @c_CartonType  NVARCHAR(10) 
      ,  @c_PickSlipNo  NVARCHAR(10)
      ,  @n_CartonNo    INT
      
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
           @n_StartTCnt    INT            
         , @b_Success      INT
         , @n_err          INT             
         , @c_errmsg       NVARCHAR(250) 

         , @c_Storerkey    NVARCHAR(15)
         , @n_CTNQty       INT
         , @n_MaxSkuHeight FLOAT
         , @n_BottomWidth  FLOAT
         , @n_Cube         FLOAT
      
   SET @c_Storerkey   = ''
   SET @n_CTNQty      = 0
   SET @n_MaxSkuHeight= 0.00
   SET @n_BottomWidth = 0.00
   SET @n_Cube        = 0.00

   SELECT @c_Storerkey = PD.Storerkey
         ,@n_CTNQty    = ISNULL(SUM(PD.Qty),0)
         ,@n_MaxSkuHeight = ISNULL(MAX(SKU.Height),0.00)
   FROM PACKDETAIL PD WITH (NOLOCK)
   JOIN SKU           WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                    AND(PD.Sku = SKU.Sku)
   WHERE PD.PickSlipNo = @c_PickSlipNo
   AND   PD.CartonNo   = @n_CartonNo
   GROUP BY PD.Storerkey


   SELECT @n_BottomWidth = CASE WHEN ISNUMERIC(CL.UDF01) = 1 THEN ISNULL(CONVERT(FLOAT, CL.UDF01),0.00) ELSE 0 END
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'CTNTypMeas'
   AND   CL.Code     = @c_CartonType
   AND   CL.Storerkey= @c_Storerkey

   --SET @n_Cube = @n_CTNQty * @n_MaxSkuHeight * @n_BottomWidth
   SET @n_Cube = @n_MaxSkuHeight * @n_BottomWidth

   INSERT INTO #TMP_CTNTYPMEAS
         (  CartonizationKey  
         ,  CartonType        
         ,  Cube              
         ,  MaxWeight         
         ,  MaxCount          
         ,  CartonWeight      
         ,  CartonLength      
         ,  CartonWidth       
         ,  CartonHeight
         )
   SELECT   CartonizationKey  
         ,  CartonType        
         ,  @n_Cube
         ,  ISNULL(MaxWeight,0)
         ,  ISNULL(MaxCount,0)
         ,  ISNULL(CartonWeight,0)
         ,  ISNULL(CartonLength,0)
         ,  ISNULL(CartonWidth,0)
         ,  ISNULL(CartonHeight,0)
   FROM CARTONIZATION WITH (NOLOCK)
   WHERE CartonizationGroup = @c_CartonGroup
   AND   CartonType = @c_CartonType

   QUIT_SP:
END -- procedure

GO
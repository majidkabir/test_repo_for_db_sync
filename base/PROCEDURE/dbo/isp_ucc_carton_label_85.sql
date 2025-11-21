SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_UCC_Carton_Label_85                            */
/* Creation Date:23-MAY-2019                                            */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-9129 -[CN] Converse Carton Label (CR)                  */
/*                                                                      */
/* Input Parameters: storerkey,PickSlipNo, CartonNoStart, CartonNoEnd   */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_ucc_carton_label_85                                 */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_85] (
           @c_StorerKey      NVARCHAR(20), 
           @c_PickSlipNo     NVARCHAR(20),
           @c_StartCartonNo  NVARCHAR(20),
           @c_EndCartonNo    NVARCHAR(20)
            )
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @n_ttlctn          INT
         , @n_Page            INT

   SET @n_ttlctn          = 1
   SET @n_Page            = 1
         


  CREATE TABLE #TMP_LCartonLABEL85 (
          rowid           int NOT NULL identity(1,1) PRIMARY KEY,
          OrdExtOrdKey    NVARCHAR(50) NULL,
          Consigneekey    NVARCHAR(45) NULL,
          cartonno        INT NULL,
          TTLCtn          INT NULL,
          SKUStyle        NVARCHAR(20) NULL,
          SKUSize         NVARCHAR(10) NULL,
          PDQty           INT,
          SKUColor        NVARCHAR(20) NULL,
          PageNo          INT,
          pdLabelno       NVARCHAR(20) NULL)        

   
   
   SELECT @n_ttlctn = MAX(cartonno)
   FROM PACKDETAIL WITH (NOLOCK)
   WHERE Pickslipno = @c_PickSlipNo
   AND   Storerkey = @c_StorerKey
          
          
   INSERT INTO #TMP_LCartonLABEL85(OrdExtOrdKey,Consigneekey,cartonno,
                                   TTLCtn,SKUStyle,SKUSize,PDQty,SKUColor,PageNo,
                                   pdLabelno )   
   SELECT DISTINCT  ORDERS.Externorderkey
         ,  ORDERS.consigneekey                           
         ,  PADET.CartonNo
         ,  @n_ttlctn
         ,  ISNULL(RTRIM(S.Style),'')
         ,  ISNULL(RTRIM(S.Size),'')
         ,  PADET.qty
         ,  ISNULL(RTRIM(S.color),'')
         ,  @n_Page
         ,  PADET.labelno              
   FROM PACKHEADER PAH WITH (NOLOCK)
   JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno
   JOIN ORDERS     WITH (NOLOCK) ON ORDERS.orderkey=PAH.orderkey
   JOIN SKU S WITH (NOLOCK) ON S.storerkey = PADET.Storerkey and S.sku = PADET.SKU     
   WHERE PAH.Pickslipno = @c_PickSlipNo
   AND   PAH.Storerkey = @c_StorerKey
   AND PADET.cartonno >= CAST(@c_StartCartonNo as INT) AND PADET.CartonNo <=  CAST(@c_EndCartonNo as INT)
   ORDER BY  PADET.CartonNo

        SELECT OrdExtOrdKey,Consigneekey,cartonno,
               TTLCtn,SKUStyle,SKUSize,PDQty,SKUColor,PageNo,
               pdLabelno
        FROM   #TMP_LCartonLABEL85
        ORDER BY cartonno,SKUStyle,SKUSize,SKUColor


END

GO
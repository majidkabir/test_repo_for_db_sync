SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_Packing_List_69_2                                       */
/* Creation Date: 25-SEP-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-10695 - Copied from r_dw_packlist_01_tw                 */
/*        :                                                             */
/* Called By: r_dw_print_packlist_11_2                                  */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_Packing_List_69_2]
            @c_PickSlipNo     NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @b_Success         INT
         , @n_Err             INT
         , @c_Errmsg          NVARCHAR(255)

         , @n_NoOfReqPSlip    INT
         , @c_Orderkey        NVARCHAR(10)
    --     , @c_PickSlipNo      NVARCHAR(10)
         , @c_PickHeaderKey   NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)

         , @c_AutoScanIn      NVARCHAR(10)
         , @c_Facility        NVARCHAR(5)      --(CS01)
         , @c_Logo            NVARCHAR(50)     --(WL01)
         , @n_MaxLine         INT
         , @n_CntRec          INT
         , @c_MaxPSlipno      NVARCHAR(10)
         , @n_LastPage        INT
         , @n_ReqLine         INT
         , @c_JCLONG          NVARCHAR(255)  

   SET @n_StartTCnt= @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_Err      = 0
   SET @c_Errmsg   = ''
   SET @c_Logo     = '' 
   SET @n_MaxLine  = 14
   SET @n_CntRec   = 1
   SET @n_LastPage = 0
   SET @n_ReqLine  = 1

   CREATE TABLE #TMP_PACK
      ( Loadkey      NVARCHAR(10)   NOT NULL
      , Orderkey     NVARCHAR(10)   NOT NULL
      , PickSlipNo   NVARCHAR(10)   NOT NULL
      , Storerkey    NVARCHAR(15)   NOT NULL
      , logo         NVARCHAR(255)  NULL    --INC0072296
      )

   CREATE TABLE #TMP_PACK11
      ( CustomerGroupName      NVARCHAR(60)   NULL
      , Loadkey                NVARCHAR(10)   NULL
      , BARCODE                NVARCHAR(100)  NULL
      , Orderkey               NVARCHAR(10)   NOT NULL
      , ExternOrderkey         NVARCHAR(50)   NOT NULL
      , Consigneekey           NVARCHAR(15)   NULL
      , C_Company              NVARCHAR(45)   NULL
      , C_Address1             NVARCHAR(45)   NULL 
      , Deliverydate           DATETIME       NULL
      , BuyerPo                NVARCHAR(20)   NULL
      , UOM                    NVARCHAR(10)   NULL
      , PickSlipno             NVARCHAR(10)   NULL
      , BARCODE2               NVARCHAR(100)  NULL
      , SKU                    NVARCHAR(20)   NULL
      , CartonNo               INT
      , Descr                  NVARCHAR(60)   NULL
      , Style                  NVARCHAR(20)   NULL
      , Color                  NVARCHAR(20)   NULL
      , Size                   NVARCHAR(10)   NULL
      , SkuGroup               NVARCHAR(10)   NULL
      , Retailsku              NVARCHAR(20)   NULL
      , Measurement            NVARCHAR(5)    NULL
      , Code                   NVARCHAR(30)   NULL
      , [Description]          NVARCHAR(250)  NULL
      , numericaldigits        NVARCHAR(4000) NULL 
      , PSNoCtnNo              NVARCHAR(100)  NULL  
      , Qty                    INT
      , PageNo                 INT
      )

      --SET @c_Facility = ''
      --SELECT @c_Facility = Facility
      --FROM LOADPLAN WITH (NOLOCK)
      --WHERE Loadkey = @c_Loadkey

      INSERT INTO #TMP_PACK11
      SELECT ST.CustomerGroupName,
             OH.Loadkey,
             dbo.fn_Encode_IDA_Code128(RTRIM(OH.Loadkey)) AS BARCODE,
             OH.Orderkey,
             OH.ExternOrderkey,
             OH.Consigneekey,
             OH.C_Company,
             OH.C_Address1,
             OH.Deliverydate,
             OH.BuyerPo,
             OD.UOM,
             PH.PickSlipno,
             dbo.fn_Encode_IDA_Code128(RTRIM(PH.PickSlipno)) AS BARCODE,
             PD.SKU,
             PD.CartonNo,
             SKU.Descr,
             SKU.Style,
             SKU.Color,
             SKU.Size,
             SKU.SkuGroup,
             SKU.Retailsku,
             SKU.Measurement,
             CK.Code,
             CK.Description,
             '2'+RIGHT(PH.PICKSLIPNO,9)+replicate('0',3-len(pd.cartonno))+cast(PD.CARTONNO as nvarchar) numericaldigits,
             dbo.fn_Encode_IDA_Code128('9'+RIGHT(PH.PICKSLIPNO,9)+replicate('0',3-len(pd.cartonno))+cast(PD.CARTONNO as nvarchar)) AS '13',
             PD.Qty,
             pageno = (Row_number() OVER (PARTITION BY PH.PickSlipNo ORDER BY PH.PickSlipNo, OH.Orderkey,SKU.sku asc)) / @n_MaxLine
      FROM PACKHEADER        PH  WITH (NOLOCK)
      JOIN PACKDETAIL        PD  WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
      JOIN ORDERS            OH  WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)
      JOIN (SELECT DISTINCT OD1.ORDERKEY, OD1.STORERKEY, OD1.SKU, OD1.UOM FROM ORDERDETAIL OD1 WITH (NOLOCK) 
                     JOIN PACKHEADER PH1 WITH (NOLOCK) ON (OD1.STORERKEY = PH1.STORERKEY AND OD1.ORDERKEY = PH1.ORDERKEY)
                     JOIN PACKDETAIL PD1 WITH (NOLOCK) ON (PH1.PICKSLIPNO = PD1.PICKSLIPNO)
                     JOIN LOADPLANDETAIL LPD1 WITH (NOLOCK) ON (LPD1.ORDERKEY = OD1.ORDERKEY)
                     WHERE PH1.PICKSLIPNO = LEFT(@c_PickSlipNo,10))  	
                     --WHERE LPD1.Loadkey = @c_LoadKey)
                     AS OD ON (OH.ORDERKEY = OD.ORDERKEY AND PD.STORERKEY = OD.STORERKEY AND PD.SKU = OD.SKU)
      --JOIN ORDERDETAIL   OD  WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
      --                                     AND(PD.Storerkey= OD.Storerkey) AND (PD.Sku = OD.Sku)
      JOIN STORER            ST  WITH (NOLOCK) ON (OH.Storerkey= ST.Storerkey)
      JOIN SKU               SKU WITH (NOLOCK) ON (OD.Storerkey= SKU.Storerkey) AND (OD.Sku = SKU.Sku)
      JOIN PACK              PK  WITH (NOLOCK) ON (SKU.Packkey = PK.Packkey)
      JOIN LOADPLANDETAIL    LPD WITH (NOLOCK) ON (LPD.ORDERKEY = OH.ORDERKEY)
      LEFT JOIN CODELKUP     CK  WITH (NOLOCK) ON (SKU.Storerkey = CK.Storerkey AND SKU.SKUGROUP=CK.CODE)  AND   CK.LISTNAME ='SKUGROUP'
      WHERE PH.Storerkey='POI'
      AND   (OH.Status >= '3')
      AND   (OH.Status <> 'CANC')
      AND   (OH.Type in ('NORMAL','POITRF'))
      --AND   (LPD.Loadkey = @c_LoadKey)
      AND   (PH.PickSlipNo = LEFT(@c_PickSlipNo,10))
      --AND   (PD.CartonNo >= CAST(:as_FromCartonNo AS INT) )
      --AND   (PD.CartonNo <= CAST(:as_ToCartonNo AS INT ))
      
QUIT_SP:

   IF @n_Continue = 3
   BEGIN
      IF @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

  SELECT @c_MaxPSlipno = MAX(pickslipno)
         ,@n_CntRec = COUNT(1)
         ,@n_LastPage = MAX(tp.Pageno)
  FROM #TMP_PACK11 AS tp
  GROUP BY tp.PickSlipNo


  IF @n_CntRec > @n_MaxLine
  BEGIN
   SET @n_ReqLine = @n_MaxLine - (@n_CntRec - @n_MaxLine) - 1
  END
  ELSE
  BEGIN
   SET @n_ReqLine = @n_MaxLine - @n_CntRec - 1
  END

  --SELECT @c_MaxPSlipno '@c_MaxPSlipno',@n_CntRec '@n_CntRec',@n_LastPage '@n_LastPage',@n_ReqLine '@n_ReqLine'

  WHILE @n_ReqLine >= 1
  BEGIN

   --SELECT @n_ReqLine '@n_ReqLine'
   INSERT INTO #TMP_PACK11
   SELECT TOP 1   CustomerGroupName   
                , Loadkey            
                , BARCODE            
                , Orderkey           
                , ExternOrderkey     
                , Consigneekey       
                , C_Company          
                , C_Address1         
                , Deliverydate       
                , BuyerPo            
                , UOM                
                , @c_MaxPSlipno         
                , BARCODE2           
                , SKU                
                , CartonNo           
                , ''              
                , ''              
                , ''              
                , ''               
                , SkuGroup           
                , Retailsku          
                , ''        
                , Code               
                , ''      
                , numericaldigits    
                , PSNoCtnNo          
                , ''                
                , @n_LastPage  
      FROM #TMP_PACK11 AS tp
      WHERE tp.PickSlipNo= @c_MaxPSlipno
      AND tp.Pageno = @n_LastPage

      SET @n_ReqLine  = @n_ReqLine - 1

  END

  SELECT * FROM #TMP_PACK11 AS tp
  ORDER BY orderkey, cartonno,
           CASE WHEN style = '' THEN 2 ELSE 1 END,tp.Pageno

END -- procedure

GO
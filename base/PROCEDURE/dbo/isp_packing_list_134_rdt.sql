SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_Packing_List_134_rdt                           */
/* Creation Date: 2023-06-13                                            */
/* Copyright: IDS                                                       */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose: WMS-22750 -[KR] lululemon B2C Pickslip - NEW                */
/*                                                                      */
/* Called By: r_dw_Packing_List_134_rdt                                 */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/*  2023-06-13  CSCHONG 1.0   Devops Scripts Combine                    */
/************************************************************************/

CREATE   PROC [dbo].[isp_Packing_List_134_rdt]
         (  @c_PickSlipNo  NVARCHAR(10)
         ,  @c_Orderkey    NVARCHAR(10) = ''
         ,  @c_Type        NVARCHAR(1) = ''
         ,  @c_DWCategory  NVARCHAR(1) = 'H'
         ,  @n_cartonNo    INT = 1
         ,  @n_RecGroup    INT         = 0
         )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_NoOfLine  INT
         , @n_TotDetail INT
         , @n_LineNeed  INT
         , @n_SerialNo  INT
         , @b_debug     INT

  DECLARE   @c_ordkey NVARCHAR(10)
           ,@c_GPickslipno NVARCHAR(10)
           ,@n_GetCartonno INT
           ,@n_CartonNo1 INT
           ,@n_cartonqty INT
           ,@n_MaxRecGrp INT

  DECLARE  @c_A1           NVARCHAR(200)  
         , @c_A2           NVARCHAR(200)  
         , @c_A3           NVARCHAR(200)  
         , @c_A4           NVARCHAR(200)  
         , @c_A5           NVARCHAR(200)  
         , @c_A6           NVARCHAR(200)  
         , @c_A7           NVARCHAR(200)  
         , @c_A8           NVARCHAR(200)  
         , @c_A9           NVARCHAR(200)  
         , @c_A10          NVARCHAR(200)  
         , @c_A11          NVARCHAR(200)  
         , @c_A12          NVARCHAR(200)  
         , @c_A13          NVARCHAR(200)  
         , @c_A14          NVARCHAR(200)  
         , @c_A15          NVARCHAR(200)  
         , @c_A16          NVARCHAR(200)  
         , @c_A17          NVARCHAR(200)  
         , @c_A18          NVARCHAR(200)  
         , @c_A19          NVARCHAR(200)  
         , @c_A20          NVARCHAR(200)  
         , @c_getstorerkey NVARCHAR(20) = N''  
         , @c_getcountry   NVARCHAR(45) = N''  
         , @c_getshipperkey NVARCHAR(45) = N''  
         , @c_A21          NVARCHAR(200)  

   SET @n_NoOfLine = 10
   SET @n_TotDetail= 0
   SET @n_LineNeed = 0
   SET @n_SerialNo = 0
   SET @b_debug    = 0

   SET @n_cartonno1 = 0
   SET @n_cartonqty=0
   --SET @n_MaxRecGrp = 0

   IF ISNULL(@c_Orderkey,'') = ''
      BEGIN

        SELECT TOP 1 @c_Orderkey = PH.Orderkey
        FROM PACKHEADER PH WITH (NOLOCK)
        WHERE PH.PickSlipNo = @c_pickslipno

      END

 SET @c_getstorerkey = N''  
 SET @c_getcountry = N''  
 SET @c_getshipperkey = N''  
  
   SELECT TOP 1 @c_getstorerkey = OH.StorerKey  
               ,@c_getcountry=OH.C_Country
               ,@c_getshipperkey = OH.ShipperKey  
   FROM ORDERS OH WITH (NOLOCK)  
   WHERE oh.OrderKey=@c_Orderkey


 SELECT @c_A1 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A1' THEN ISNULL(RTRIM(CL.Notes), '')  
                                  ELSE '' END)  
                       , '')  
        , @c_A2 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A2' THEN ISNULL(RTRIM(CL.Notes), '')  
                                  ELSE '' END)  
                       , '')  
        , @c_A3 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A3' THEN ISNULL(RTRIM(CL.Notes), '')  
                                  ELSE '' END)  
                       , '')  
        , @c_A4 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A4' THEN ISNULL(RTRIM(CL.Notes), '')  
                                  ELSE '' END)  
                       , '')  
        , @c_A5 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A5' THEN ISNULL(RTRIM(CL.Notes), '')  
                                  ELSE '' END)  
                       , '')  
        , @c_A6 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A6' THEN ISNULL(RTRIM(CL.Notes), '')  
                                  ELSE '' END)  
                       , '')  
        , @c_A7 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A7' THEN ISNULL(RTRIM(CL.Notes), '')  
                                  ELSE '' END)  
                       , '')  
        , @c_A8 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A8' THEN ISNULL(RTRIM(CL.Notes), '')  
                                  ELSE '' END)  
                       , '')  
        , @c_A9 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A9' THEN ISNULL(RTRIM(CL.Notes), '')  
                                  ELSE '' END)  
                       , '')  
        , @c_A10 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A10' THEN ISNULL(RTRIM(CL.Notes), '')  
                                   ELSE '' END)  
                        , '')  
        , @c_A11 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A11' THEN ISNULL(RTRIM(CL.Notes), '')  
                                   ELSE '' END)  
                        , '')  
        , @c_A12 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A12' THEN ISNULL(RTRIM(CL.Notes), '')  
                                   ELSE '' END)  
                        , '')  
        , @c_A13 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A13' THEN ISNULL(RTRIM(CL.Notes), '')  
                                   ELSE '' END)  
                        , '')  
        , @c_A14 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A14' THEN ISNULL(RTRIM(CL.Notes), '')  
                                   ELSE '' END)  
                        , '')  
        , @c_A15 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A15' THEN ISNULL(RTRIM(CL.Notes), '')  
                                   ELSE '' END)  
                        , '')  
        , @c_A16 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A16' THEN ISNULL(RTRIM(CL.Notes), '')  
                                   ELSE '' END)  
                        , '')  
        , @c_A17 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A17' THEN ISNULL(RTRIM(CL.Notes), '')  
                                   ELSE '' END)  
                        , '')  
        , @c_A18 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A18' THEN ISNULL(RTRIM(CL.Notes), '')  
                                   ELSE '' END)  
                        , '')  
        , @c_A19 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A19' THEN ISNULL(RTRIM(CL.Notes), '')  
                                   ELSE '' END)  
                        , '')  
        , @c_A20 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A20' THEN ISNULL(RTRIM(CL.Notes), '')  
                                   ELSE '' END)  
                        , '')  
        , @c_A21 = ISNULL(MAX(CASE WHEN CL.UDF01 = 'A21' THEN ISNULL(RTRIM(CL.Notes), '')  
                                   ELSE '' END)  
                        , '')  
   FROM CODELKUP CL WITH (NOLOCK)  
   WHERE CL.LISTNAME = 'LUPACKLIST' AND CL.Storerkey = @c_getstorerkey  
   AND(CL.UDF02 = @c_getcountry)
   AND(CL.UDF03 = @c_getshipperkey)


  IF ISNULL(@c_A21,'') = ''
  BEGIN
   SELECT TOP 1 @c_A21 = ISNULL(RTRIM(CL.Notes), '')
   FROM CODELKUP CL WITH (NOLOCK)  
   WHERE CL.LISTNAME = 'LUPACKLIST' AND CL.Storerkey = @c_getstorerkey  
   AND CL.udf01='A21'
   AND (CL.UDF02 = 'SD')
  END

   IF @c_DWCategory = 'D'
   BEGIN
      GOTO Detail
   END


   HEADER:

      CREATE TABLE #TMP_PICKHDR
            (  SeqNo         INT  IDENTITY(1,1) NOT NULL
            ,  OrderKey      NVARCHAR(10)
            ,  InvoiceNo     NVARCHAR(45)
            ,  Shipmentdate  NVARCHAR(10)
            ,  ShipmentMode  NVARCHAR(45)
            ,  Carton        NVARCHAR(15)
            ,  CartonID      NVARCHAR(20)
            ,  B_Company     NVARCHAR(45)
            ,  B_Address     NVARCHAR(150)
            ,  B_CityZip     NVARCHAR(150)
            ,  B_Country     NVARCHAR(30)
            ,  C_Company     NVARCHAR(45)
            ,  C_Address     NVARCHAR(150)
            ,  C_CityZip     NVARCHAR(150)
            ,  C_Country     NVARCHAR(30)
            ,  Notes2        NVARCHAR(4000)
            ,  C_Phone1      NVARCHAR(18)
            ,  MsgTo         NVARCHAR(70)
            ,  MsgFrom       NVARCHAR(70)
            ,  MSGDET        NVARCHAR(70)
            ,  PaymentMethod NVARCHAR(140)
            ,  RecGroup      INT
            ,  A1            NVARCHAR(4000)
            ,  A2            NVARCHAR(4000)
            ,  A3            NVARCHAR(4000)
            ,  A4            NVARCHAR(4000)
            ,  A5            NVARCHAR(4000)
            ,  A6            NVARCHAR(4000)
            ,  A7            NVARCHAR(4000)
            ,  A8            NVARCHAR(4000)
            ,  A9            NVARCHAR(4000)
            ,  A10           NVARCHAR(4000)
            ,  A11           NVARCHAR(4000)
            ,  A17           NVARCHAR(4000)
            ,  PickSlipNo    NVARCHAR(10)
            ,  CartonNo      INT
            ,  Salesman      NVARCHAR(30)     
            ,  A21           NVARCHAR(4000)  
            ,  DevicePosition NVARCHAR(10)              
            )



      INSERT INTO #TMP_PICKHDR
            (  OrderKey
            ,  InvoiceNo
            ,  Shipmentdate
            ,  ShipmentMode
            ,  Carton
            ,  CartonID
            ,  B_Company
            ,  B_Address
            ,  B_CityZip
            ,  B_Country
            ,  C_Company
            ,  C_Address
            ,  C_CityZip
            ,  C_Country
            ,  Notes2
            ,  C_Phone1
            ,  MsgTo
            ,  MsgFrom
            ,  MSGDET
            ,  PaymentMethod
            ,  RecGroup
            ,  A1
            ,  A2
            ,  A3
            ,  A4
            ,  A5
            ,  A6
            ,  A7
            ,  A8
            ,  A9
            ,  A10
            ,  A11
            ,  A17
            ,  Pickslipno
            ,  CartonNo
            ,  Salesman     
            ,  A21
            ,  DevicePosition                                              
            )
      SELECT DISTINCT @c_orderkey,
               RTRIM(SubString(ORD.M_Address3,1,case when charindex('_',ORD.M_Address3,1)=0 THEN 45 ELSE charindex('_',ORD.M_Address3,1)-1 END)) AS OrderNo 
               ,CONVERT(NVARCHAR(10),CASE WHEN ORD.status='9' THEN ORD.Editdate ELSE ORD.DeliveryDate END,103) AS ShipmentDate
               ,ORD.M_Address2 AS ShipmentMode
            ,(convert(nvarchar(5),PD.CartonNo) + ' of ' + convert(nvarchar(5),PH.TTLCNTS)) As Carton
            ,PD.Labelno
            ,CASE WHEN EXISTS(SELECT 1 FROM CODELKUP CLR WITH (NOLOCK) WHERE CLR.listname='LUPACKLIST' and CLR.UDF01='6' and CLR.UDF02=ORD.C_Country and CLR.UDF03=ORD.Shipperkey)
            THEN '' ELSE ORD.B_Company END
            ,CASE WHEN EXISTS(SELECT 1 FROM CODELKUP CLR WITH (NOLOCK) WHERE CLR.listname='LUPACKLIST' and CLR.UDF01='7' and CLR.UDF02=ORD.C_Country and CLR.UDF03=ORD.Shipperkey)
            THEN '' ELSE (RTRIM(ORD.B_Address1) + RTRIM(ORD.B_Address2) + RTRIM(ORD.B_Address3)) END AS BillToAdd
            ,CASE WHEN EXISTS(SELECT 1 FROM CODELKUP CLR WITH (NOLOCK) WHERE CLR.listname='LUPACKLIST' and CLR.UDF01='8' and CLR.UDF02=ORD.C_Country and CLR.UDF03=ORD.Shipperkey)
            THEN '' ELSE (RTRIM(ORD.B_Address4)+','+' ' +RTRIM(ORD.B_Country)+','+' ' + RTRIM(ORD.B_Zip)) END AS BillToCity
            ,CASE WHEN EXISTS(SELECT 1 FROM CODELKUP CLR WITH (NOLOCK) WHERE CLR.listname='LUPACKLIST' and CLR.UDF01='11' and CLR.UDF02=ORD.C_Country and CLR.UDF03=ORD.Shipperkey)
            THEN '' ELSE B_Country END AS B_Country
            ,C_Company,(RTRIM(ORD.C_Address1)+RTRIM(ORD.C_Address2)+RTRIM(ORD.C_Address3)) As ShipToAdd,
               (RTRIM(ORD.C_Address4)+','+' ' +RTRIM(ORD.C_Country)+','+' ' +RTRIM(ORD.C_Zip))AS ShipToCity,C_Country
            ,CASE WHEN EXISTS(SELECT 1 FROM CODELKUP CLR WITH (NOLOCK) WHERE CLR.listname='LUPACKLIST' and CLR.UDF01='18' and CLR.UDF02=ORD.C_Country and CLR.UDF03=ORD.Shipperkey)
            THEN '' ELSE ORD.Notes2 END
            ,CASE WHEN EXISTS(SELECT 1 FROM CODELKUP CLR WITH (NOLOCK) WHERE CLR.listname='LUPACKLIST' and CLR.UDF01='19' and CLR.UDF02=ORD.C_Country and CLR.UDF03=ORD.Shipperkey)
            THEN '' ELSE ORD.C_Phone1 END
            ,CASE WHEN EXISTS(SELECT 1 FROM CODELKUP CLR WITH (NOLOCK) WHERE CLR.listname='LUPACKLIST' and CLR.UDF01='20' and CLR.UDF02=ORD.C_Country and CLR.UDF03=ORD.Shipperkey)
            THEN '' ELSE SubString(DI.Data,141,70) END AS ToMsg
            ,CASE WHEN EXISTS(SELECT 1 FROM CODELKUP CLR WITH (NOLOCK) WHERE CLR.listname='LUPACKLIST' and CLR.UDF01='21' and CLR.UDF02=ORD.C_Country and CLR.UDF03=ORD.Shipperkey)
            THEN '' ELSE SubString(DI.Data,211,70) END AS FromMsg
            ,CASE WHEN EXISTS(SELECT 1 FROM CODELKUP CLR WITH (NOLOCK) WHERE CLR.listname='LUPACKLIST' and CLR.UDF01='22' and CLR.UDF02=ORD.C_Country and CLR.UDF03=ORD.Shipperkey)
            THEN '' ELSE (RTRIM(SubString(DI.Data,281,70))+' '+ RTRIM(SubString(DI.Data,351,70))+' '+ RTRIM(SubString(DI.Data,421,70))) END AS MSG
            ,RTRIM(SubString(DI.Data,1,70))+'     '+
               RTRIM(SubString(DI.Data,71,70)),(Row_Number() OVER (PARTITION BY ORD.Orderkey,PH.PickslipNo,PD.CartonNo ORDER BY ORD.Orderkey Asc) - 1)/@n_NoOfLine
            ,  @c_A1
            ,  @c_A2
            ,  @c_A3
            ,  @c_A4
            ,  @c_A5
            ,  @c_A6
            ,  @c_A7
            ,  @c_A8
            ,  @c_A9
            ,  @c_A10
            ,  @c_A11
            ,  @c_A17
            ,  PH.Pickslipno,pd.cartonno
            ,  ORD.Salesman  
            ,  @c_A21 
            , ISNULL(PT.DevicePosition,'')
      FROM ORDERS ORD WITH (NOLOCK)
      JOIN  ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=ORD.OrderKey
      JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = ORD.Orderkey
      JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
      JOIN DOCINFO DI WITH (NOLOCK) ON DI.Key1=ORD.Orderkey AND DI.TableName='Orders' AND DI.Storerkey=ORD.storerkey
    --  JOIN dbo.fnc_GetPackinglist134Label (@c_orderkey) lbl ON (lbl.Orderkey = ORD.Orderkey)
      LEFT JOIN PACKTASK PT WITH (NOLOCK) ON PT.orderkey = ORD.orderkey
      WHERE ORD.Orderkey = @c_Orderkey AND PH.Pickslipno = @c_Pickslipno
      AND ORD.type='LULUECOM' and ORD.Status>='5'

IF @b_debug = 1
BEGIN
   INSERT INTO TRACEINFO (TraceName, timeIn, Step1, Step2, step3, step4, step5)
   VALUES ('isp_Packing_List_134_rdt', getdate(), @c_DWCategory, @c_orderkey, @c_pickslipno, '', suser_name())
END

      SELECT OrderKey
            ,  InvoiceNo
            ,  Shipmentdate
            ,  ShipmentMode
            ,  Carton
            ,  CartonID
            ,  B_Company
            ,  B_Address
            ,  B_CityZip
            ,  B_Country
            ,  C_Company
            ,  C_Address
            ,  C_CityZip
            ,  C_Country
            ,  Notes2
            ,  C_Phone1
            ,  MsgTo
            ,  MsgFrom
            ,  MSGDET
            ,  PaymentMethod
            ,  RecGroup
            ,  A1
            ,  A2
            ,  A3
            ,  A4
            ,  A5
            ,  A6
            ,  A7
            ,  A8
            ,  A9
            ,  A10
            ,  A11
            ,  A17
            ,  CartonNo
            ,  Salesman    
            ,  A21
             , DevicePosition             
      FROM #TMP_PICKHDR
      ORDER BY SeqNo

      DROP TABLE #TMP_PICKHDR
      GOTO QUIT_SP
   DETAIL:
      CREATE TABLE #TMP_PICKDETSKU
         (  Carton            INT
         ,  DropID            NVARCHAR(20)
         ,  Orderkey          NVARCHAR(10)
         ,  OrderLineNumber   NVARCHAR(5)
         ,  ItemDescr         NVARCHAR(55)
         ,  Sku               NVARCHAR(20)
         ,  ItemColor         NVARCHAR(25)
         ,  ItemSize          NVARCHAR(18)
         ,  QTY               INT
         ,  RecGroup          INT
         ,  A12               NVARCHAR(4000)
         ,  A13               NVARCHAR(4000)
         ,  A14               NVARCHAR(4000)
         ,  A15               NVARCHAR(4000)
         ,  A16               NVARCHAR(4000)
       -- ,  A17              NVARCHAR(4000)
         ,  A18               NVARCHAR(4000)
         ,  TTLQty            INT
         ,  ShowCol           INT
         ,  UnitPrice         FLOAT
         ,  ExtPrice          FLOAT
         ,  A19               NVARCHAR(4000)
         ,  A20               NVARCHAR(4000)
         )

     CREATE TABLE #TMP_CartonGrp
         (  Orderkey       NVARCHAR(10),
            CartonNo       INT,
            RecGroup       INT
          )

      INSERT INTO #TMP_PICKDETSKU
         (  Carton,DropID
         ,  Orderkey
         ,  OrderLineNumber
         ,  Sku
         ,  ITEMDescr
         ,  ItemColor
         ,  ItemSize
         ,  Qty
         ,  RecGroup
         ,  A12
         ,  A13
         ,  A14
         ,  A15
         ,  A16
         --,  A17
         ,  A18
         ,  TTLQty
         ,  ShowCol
         ,  UnitPrice
         ,  ExtPrice
         ,  A19
         ,  A20
         )
      SELECT DISTINCT PACKDET.CartonNo As Carton,PACKDET.Labelno,ORDDET.Orderkey,ORDDET.OrderLineNumber,PACKDET.SKU,SubString(DI.Data,26,55) AS DESCR,SubString(DI.Data,1,25) AS [COLOR],
      ORDDET.Userdefine07 as [size],Sum(PACKDET.Qty),(Row_Number() OVER (PARTITION BY ORDDET.Orderkey ORDER BY ORDDET.Orderkey Asc) - 1)/@n_NoOfLine,
      @c_A12 ,  @c_A13,  @c_A14,  @c_A15,  @c_A16,  @c_A18,0,0,ORDDET.UnitPrice,ORDDET.ExtendedPrice,@c_a19,@c_a20
      FROM OrderDetail ORDDET WITH (NOLOCK)
      JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = ORDDET.Orderkey
      --JOIN PICKDETAIL PICKDET WITH (NOLOCK) ON PICKDET.Orderkey=ORDDET.Orderkey AND PICKDET.Orderlinenumber = ORDDET.Orderlinenumber
      JOIN PACKDETAIL PACKDET WITH (NOLOCK) ON PACKDET.Pickslipno=PH.Pickslipno AND PACKDET.SKU = ORDDET.SKU
      JOIN DOCINFO DI WITH (NOLOCK) ON DI.Key1=ORDDET.Orderkey AND DI.TableName='Orderdetail' AND DI.Storerkey=@c_getstorerkey
      AND ORDDET.Orderlinenumber=DI.Key2
      --JOIN dbo.fnc_GetPackinglist18Label (@c_orderkey) lbl ON (lbl.Orderkey = ORDDET.Orderkey)
      WHERE ORDDET.Orderkey = @c_Orderkey
      AND   PACKDET.CartonNo =  @n_cartonNo
     -- AND   (convert(nvarchar(5),PACKDET.CartonNo) + ' of ' + convert(nvarchar(5),PH.TTLCNTS)) = @c_cartonNo
     -- GROUP BY (convert(nvarchar(5),PACKDET.CartonNo) + ' of ' + convert(nvarchar(5),PH.TTLCNTS)),PACKDET.LabelNo,ORDDET.Orderkey,ORDDET.OrderLineNumber,PACKDET.SKU,SubString(DI.Data,26,55) ,SubString(DI.Data,1,25),
      GROUP BY PACKDET.CartonNo ,PACKDET.LabelNo,ORDDET.Orderkey,ORDDET.OrderLineNumber,PACKDET.SKU,SubString(DI.Data,26,55) ,SubString(DI.Data,1,25),
      ORDDET.Userdefine07,ORDDET.UnitPrice,ORDDET.ExtendedPrice

      SELECT @n_cartonqty = sum(qty)
      FROM packheader PH WITH (NOLOCK)
      JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno=PH.PickslipNo
      WHERE orderkey =@c_OrderKey
      AND PD.CartonNo = @n_CartonNo
      GROUP BY Cartonno

       INSERT INTO #TMP_CartonGrp (Orderkey,CartonNo,RecGroup)
      SELECT DISTINCT ORDDET.Orderkey,PACKDET.CartonNo,(Row_Number() OVER (PARTITION BY ORDDET.Orderkey ORDER BY ORDDET.Orderkey Asc) - 1)/@n_NoOfLine
      FROM OrderDetail ORDDET WITH (NOLOCK)
      JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = ORDDET.Orderkey
      JOIN PACKDETAIL PACKDET WITH (NOLOCK) ON PACKDET.Pickslipno=PH.Pickslipno AND PACKDET.SKU = ORDDET.SKU
      WHERE ORDDET.Orderkey = @c_OrderKey
      AND   PACKDET.CartonNo =  @n_CartonNo

     SET @n_MaxRecGrp = 0

     SELECT @n_MaxRecGrp =  MAX(RecGroup)
      FROM #TMP_CartonGrp
      WHERE orderkey =@c_OrderKey
      AND CartonNo = @n_CartonNo

      UPDATE #TMP_PICKDETSKU
      SET ttlqty = @n_cartonqty
      ,showCol = CASE WHEN @n_MaxRecGrp = RecGroup THEN 1 ELSE 0 END
      WHERE orderkey =@c_OrderKey
      AND Carton = @n_CartonNo

IF @b_debug = 1
BEGIN

   INSERT INTO TRACEINFO (TraceName, timeIn, Step1, Step2, step3, step4, step5)
   VALUES ('isp_Packking_list_134_rdt', getdate(), @c_DWCategory, @c_Orderkey, @c_Pickslipno, '', suser_name())
END
      SELECT Carton,DropID
         ,  Orderkey
         ,  OrderLineNumber
         ,  Sku
         ,  ItemDescr
         ,  ItemColor
         ,  ItemSize
         ,  Qty
         ,  RecGroup
         ,  A12
         ,  A13
         ,  A14
         ,  A15
         ,  A16
     --    ,  A17
         ,  A18
         , TTLQty
         , ShowCol
         , UnitPrice,ExtPrice,A19,A20
      FROM #TMP_PICKDETSKU TMP
      WHERE TMP.RecGroup = @n_RecGroup
      AND TMP.Carton = @n_CartonNo



      DROP TABLE #TMP_PICKDETSKU
   QUIT_SP:
END

GO
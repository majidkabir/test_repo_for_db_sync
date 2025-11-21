SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Packing_List_18                                */
/* Creation Date: 2015-04-20                                            */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#339440 - Lululemon ECOM Packing List                    */
/*                                                                      */
/* Called By: r_dw_Packing_List_18                                      */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 2017-Feb-06  CSCHONG 1.0   WMS-1014-Revise InvoiceNo logic (CS01)    */
/* 2017-Dec-13  WLCHOOI 1.1   WMS-3608-Updated mapping for 6-11,		*/
/*							         18-22, A1-A18 (WL01)				*/
/* 2018-Apr-16  CSCHONG 1.2   WMS-4512 Add New Field (CS01)             */
/************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_18]
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

  DECLARE @c_ordkey NVARCHAR(10)
        ,@c_GPickslipno NVARCHAR(10)
        ,@n_GetCartonno INT
        ,@n_CartonNo1 INT
        ,@n_cartonqty INT
        ,@n_MaxRecGrp INT
   
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
            ,  Salesman      NVARCHAR(30)                          --(CS02)
           -- ,  Qty           INT
          --  ,  ShowCOL       INT
          --  ,  A18           NVARCHAR(4000)
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
            ,  Salesman                                          --(CS02)
         --   ,  Qty
       --     ,  ShowCOL
         --   ,  A18    
            )
      SELECT DISTINCT @c_orderkey,--ORD.Invoiceno AS OrderNo,   --(CS01)
               RTRIM(SubString(ORD.M_Address3,1,case when charindex('_',ORD.M_Address3,1)=0 THEN 45 ELSE charindex('_',ORD.M_Address3,1)-1 END)) AS OrderNo --(CS01)
               ,CONVERT(NVARCHAR(10),CASE WHEN ORD.status='9' THEN ORD.Editdate ELSE ORD.DeliveryDate END,103) AS ShipmentDate
               ,ORD.M_Address2 AS ShipmentMode
			   ,(convert(nvarchar(5),PD.CartonNo) + ' of ' + convert(nvarchar(5),PH.TTLCNTS)) As Carton
			   ,PD.Labelno
			   /*WL01 Start*/
			   ,CASE WHEN EXISTS(SELECT 1 FROM CODELKUP CLR WITH (NOLOCK) WHERE CLR.listname='LUPACKLIST' and CLR.UDF01='6' and CLR.UDF02=ORD.C_Country and CLR.UDF03=ORD.Shipperkey) 
			   THEN '' ELSE ORD.B_Company END
			   ,CASE WHEN EXISTS(SELECT 1 FROM CODELKUP CLR WITH (NOLOCK) WHERE CLR.listname='LUPACKLIST' and CLR.UDF01='7' and CLR.UDF02=ORD.C_Country and CLR.UDF03=ORD.Shipperkey) 
			   THEN '' ELSE (RTRIM(ORD.B_Address1) + RTRIM(ORD.B_Address2) + RTRIM(ORD.B_Address3)) END AS BillToAdd 
			   ,CASE WHEN EXISTS(SELECT 1 FROM CODELKUP CLR WITH (NOLOCK) WHERE CLR.listname='LUPACKLIST' and CLR.UDF01='8' and CLR.UDF02=ORD.C_Country and CLR.UDF03=ORD.Shipperkey) 
			   THEN '' ELSE (RTRIM(ORD.B_Address4)+','+' ' +RTRIM(ORD.B_Country)+','+' ' + RTRIM(ORD.B_Zip)) END AS BillToCity
			   ,CASE WHEN EXISTS(SELECT 1 FROM CODELKUP CLR WITH (NOLOCK) WHERE CLR.listname='LUPACKLIST' and CLR.UDF01='11' and CLR.UDF02=ORD.C_Country and CLR.UDF03=ORD.Shipperkey) 
			   THEN '' ELSE B_Country END AS B_Country
			   /*WL01 End*/
			   ,C_Company,(RTRIM(ORD.C_Address1)+RTRIM(ORD.C_Address2)+RTRIM(ORD.C_Address3)) As ShipToAdd,
               (RTRIM(ORD.C_Address4)+','+' ' +RTRIM(ORD.C_Country)+','+' ' +RTRIM(ORD.C_Zip))AS ShipToCity,C_Country
			   /*WL01 Start*/
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
			   /*WL01 End*/
			   ,RTRIM(SubString(DI.Data,1,70))+'     '+
               RTRIM(SubString(DI.Data,71,70)),(Row_Number() OVER (PARTITION BY ORD.Orderkey,PH.PickslipNo,PD.CartonNo ORDER BY ORD.Orderkey Asc) - 1)/@n_NoOfLine
               ,  lbl.A1 
			   ,  lbl.A2 
			   ,  lbl.A3 
			   ,  lbl.A4 
			   ,  lbl.A5 
			   ,  lbl.A6 
			   ,  lbl.A7
			   ,  lbl.A8
			   ,  lbl.A9
			   ,  lbl.A10 
			   ,  lbl.A11 
			   ,  lbl.A17
			   ,PH.Pickslipno,pd.cartonno
			   ,ORD.Salesman                          --(CS02)
               FROM ORDERS ORD WITH (NOLOCK)
               JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = ORD.Orderkey
               JOIN PACKDETAIL PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
               JOIN DOCINFO DI WITH (NOLOCK) ON DI.Key1=ORD.Orderkey AND DI.TableName='Orders' AND DI.Storerkey='11372'
               JOIN dbo.fnc_GetPackinglist18Label (@c_orderkey) lbl ON (lbl.Orderkey = ORD.Orderkey)  
               WHERE ORD.Orderkey = @c_Orderkey AND PH.Pickslipno = @c_Pickslipno
               AND ORD.type='LULUECOM' and ORD.Status>='5'


 /* DECLARE  C_PackHeader CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
  SELECT   DISTINCT Orderkey, Pickslipno,cartonno    
  FROM     #TMP_PICKHDR WITH (NOLOCK)     
 
    
  OPEN C_PackHeader     
  FETCH NEXT FROM C_PackHeader INTO @c_OrdKey, @c_GPickslipno,@n_GetCartonNo    
    
   WHILE (@@FETCH_STATUS <> -1)     
   BEGIN
  
      SELECT @n_cartonqty = sum(qty)
      FROM packheader PH WITH (NOLOCK)
      JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno=PH.PickslipNo
      WHERE ph.pickslipno=@c_Pickslipno
      AND orderkey =@c_OrdKey
      AND PD.CartonNo = @n_GetCartonNo
      GROUP BY Cartonno

      SELECT @n_MaxRecGrp =  MAX(RecGroup)
      FROM #TMP_PICKHDR 
      WHERE pickslipno=@c_Pickslipno
      AND orderkey =@c_OrdKey
      AND CartonNo = @n_GetCartonNo

      UPDATE #TMP_PICKHDR
      SET qty = @n_cartonqty
      ,showCol = CASE WHEN @n_MaxRecGrp = RecGroup THEN 1 ELSE 0 END
      WHERE pickslipno=@c_Pickslipno
      AND orderkey =@c_OrdKey
      AND CartonNo = @n_GetCartonNo


  FETCH NEXT FROM C_PackHeader INTO @c_OrdKey, @c_GPickslipno,@n_GetCartonNo      
  END   
    
   CLOSE C_PackHeader    
   DEALLOCATE C_PackHeader */

IF @b_debug = 1
BEGIN
   INSERT INTO TRACEINFO (TraceName, timeIn, Step1, Step2, step3, step4, step5)
   VALUES ('isp_Packing_list_18', getdate(), @c_DWCategory, @c_orderkey, @c_pickslipno, '', suser_name())
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
          --  ,  A18
            ,  CartonNo
            , Salesman                      --(CS02)
          --  ,  Qty
          --  ,  ShowCol  
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
         ,  ShowCol       INT
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
         , A15              
         ,  A16              
         --,  A17              
         ,  A18 
         ,  TTLQty
         ,  ShowCol  
         )
      SELECT DISTINCT PACKDET.CartonNo As Carton,PACKDET.Labelno,ORDDET.Orderkey,ORDDET.OrderLineNumber,PACKDET.SKU,SubString(DI.Data,26,55) AS DESCR,SubString(DI.Data,1,25) AS [COLOR],
      ORDDET.Userdefine07 as [size],Sum(PACKDET.Qty),(Row_Number() OVER (PARTITION BY ORDDET.Orderkey ORDER BY ORDDET.Orderkey Asc) - 1)/@n_NoOfLine,
      lbl.A12 ,  lbl.A13,  lbl.A14,  lbl.A15,  lbl.A16,  lbl.A18,0,0 
      FROM OrderDetail ORDDET WITH (NOLOCK) 
      JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = ORDDET.Orderkey 
      --JOIN PICKDETAIL PICKDET WITH (NOLOCK) ON PICKDET.Orderkey=ORDDET.Orderkey AND PICKDET.Orderlinenumber = ORDDET.Orderlinenumber
      JOIN PACKDETAIL PACKDET WITH (NOLOCK) ON PACKDET.Pickslipno=PH.Pickslipno AND PACKDET.SKU = ORDDET.SKU 
      JOIN DOCINFO DI WITH (NOLOCK) ON DI.Key1=ORDDET.Orderkey AND DI.TableName='Orderdetail' AND DI.Storerkey='11372'
      AND ORDDET.Orderlinenumber=DI.Key2
      JOIN dbo.fnc_GetPackinglist18Label (@c_orderkey) lbl ON (lbl.Orderkey = ORDDET.Orderkey)  
      WHERE ORDDET.Orderkey = @c_Orderkey 
      AND   PACKDET.CartonNo =  @n_cartonNo     
     -- AND   (convert(nvarchar(5),PACKDET.CartonNo) + ' of ' + convert(nvarchar(5),PH.TTLCNTS)) = @c_cartonNo    
     -- GROUP BY (convert(nvarchar(5),PACKDET.CartonNo) + ' of ' + convert(nvarchar(5),PH.TTLCNTS)),PACKDET.LabelNo,ORDDET.Orderkey,ORDDET.OrderLineNumber,PACKDET.SKU,SubString(DI.Data,26,55) ,SubString(DI.Data,1,25),
      GROUP BY PACKDET.CartonNo ,PACKDET.LabelNo,ORDDET.Orderkey,ORDDET.OrderLineNumber,PACKDET.SKU,SubString(DI.Data,26,55) ,SubString(DI.Data,1,25),
      ORDDET.Userdefine07,lbl.A12 ,  lbl.A13,  lbl.A14,  lbl.A15,  lbl.A16,  lbl.A18  

    /*  INSERT INTO #TMP_SER
         (  SerialNo
         ,  RecGroup
         ,  Orderkey
         ,  Sku 
         )
      SELECT SerialNo= Row_Number() OVER (PARTITION BY TMP.Orderkey ORDER BY TMP.ExternLineNo Asc)
         ,  TMP.RecGroup
         ,  TMP.Orderkey
         ,  TMP.Sku
      FROM #TMP_ORDSKU TMP
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (TMP.Orderkey = OD.Orderkey)
                                        AND(TMP.Sku = OD.Sku)
      GROUP BY TMP.Orderkey
            ,  TMP.ExternLineNo
            ,  TMP.Sku
            ,  TMP.RecGroup

      SELECT @n_TotDetail = COUNT(1)
            ,@n_SerialNo  = MAX(SerialNo)
      FROM #TMP_SER
      WHERE #TMP_SER.RecGroup = @n_RecGroup

      IF @n_NoOfLine > @n_TotDetail
      BEGIN
         SET @n_LineNeed = @n_NoOfLine - ( @n_SerialNo % @n_NoOfLine )

         WHILE @n_LineNeed > 0
         BEGIN
            SET @n_TotDetail = @n_TotDetail + 1
            SET @n_SerialNo = @n_SerialNo + 1
            INSERT INTO #TMP_SER (SerialNo, RecGroup, Orderkey, Sku)
            VALUES (@n_SerialNo, @n_RecGroup, '', '')
            SET @n_LineNeed = @n_LineNeed - 1  
         END
      END*/
     
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
   VALUES ('isp_Packking_list_18', getdate(), @c_DWCategory, @c_Orderkey, @c_Pickslipno, '', suser_name())
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
         ,ShowCol  
      FROM #TMP_PICKDETSKU TMP                            
      WHERE TMP.RecGroup = @n_RecGroup
      AND TMP.Carton = @n_CartonNo
      

    
      DROP TABLE #TMP_PICKDETSKU
   QUIT_SP:
END       

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_GetPickSlipOrders80                            */
/* Creation Date: 03-APR-2018                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-4361 - Direct ship to NFS via BZ-DIG                   */
/*                                                                      */
/* Input Parameters: loadkey                                            */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: r_dw_print_pickorder80                                    */
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

CREATE PROC [dbo].[isp_GetPickSlipOrders80]  (
         @c_loadKey      NVARCHAR(20)

)
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @c_Ordkey          NVARCHAR(150)
         , @n_cartonno        INT
         , @c_SKU             NVARCHAR(20)
         , @n_PDqty           INT
         , @c_Orderkey        NVARCHAR(20)
         , @c_Delimiter       NVARCHAR(1)
         , @n_lineNo          INT
         , @c_Prefix          NVARCHAR(3)
         , @n_CntOrderkey     INT
         , @c_SKUStyle        NVARCHAR(100)
         , @n_CntSize         INT
         , @n_Page            INT
         , @n_PrnQty          INT
         , @n_MaxId           INT
         , @n_MaxRec          INT
         , @n_getPageno       INT
         , @n_MaxLineno       INT
         , @n_CurrentRec      INT
         , @n_qty             INT            
         , @n_MaxCartonNo     INT
         , @n_seqno           INT
         , @c_ORDRoute        NVARCHAR(20)
         , @c_busr7           NVARCHAR(30)
         , @c_VNotes2         NVARCHAR(250)
         , @c_vas             NVARCHAR(250)
         , @c_Category        NVARCHAR(20)          
         , @c_ODLineNumber    NVARCHAR(5)            
         , @c_VNote           NVARCHAR(250)           
         , @n_CntVas          INT 
         , @c_StorerKey       NVARCHAR(20)  
         , @c_Zone            NVARCHAR(30)          
         , @n_cntRefno        INT                   
         , @c_site            NVARCHAR(30)           
         , @c_PickSlipNo      NVARCHAR(20)           
         
   SET @c_Ordkey          = ''
   SET @n_cartonno        = 1
   SET @c_SKU             = ''
   SET @n_PDqty           = 0
   SET @c_Orderkey        = ''
   SET @c_Delimiter       = ','
   SET @n_lineNo          =1
   SET @n_CntOrderkey     = 1
   SET @c_SKUStyle        = ''
   SET @n_CntSize         = 1
   SET @n_Page            = 1
   SET @n_PrnQty          = 1
   SET @n_MaxLineno       = 17         
   SET @n_qty             = 0             
   SET @n_CntVas          = 1            

  CREATE TABLE #TMP_PickOrd79 (
          rowid           int identity(1,1),
          Pickslipno      NVARCHAR(20) NULL,
          loadkey         NVARCHAR(50) NULL,
          orderkey        NVARCHAR(20) NULL,
          IntVehicle      NVARCHAR(30) NULL,
          OHType          NVARCHAR(10) NULL,
          ExtOrderkey     NVARCHAR(20) NULL,
          DeliveryDate    NVARCHAR(10) NULL,
          Userdefine01    NVARCHAR(20) NULL,
          consigneekey    NVARCHAR(45) NULL,
          [State]         NVARCHAR(45) NULL,
          City            NVARCHAR(45) NULL,
          Zip             NVARCHAR(18) NULL,
          Address1        NVARCHAR(45) NULL,
          Address2        NVARCHAR(45) NULL,
          Address3        NVARCHAR(45) NULL,
          Address4        NVARCHAR(45) NULL,
          Company         NVARCHAR(45) NULL,
          ExternPOKey     NVARCHAR(20) NULL,
          Userdefine05    NVARCHAR(20) NULL,
          OHSTOP          NVARCHAR(10) NULL,
          OrderLineNumber NVARCHAR(5) NULL,
          sku             NVARCHAR(20) NULL,
          SColor          NVARCHAR(20) NULL,
          SKU_SIze        NVARCHAR(10) NULL,
          Altsku          NVARCHAR(20) NULL,
          PDQty           INT, 
          VAS             NVARCHAR(250) NULL)           
                                                           
  CREATE TABLE #TEMPVASPOrd79 (
   Pickslipno      NVARCHAR(20) NULL,
   loadkey         NVARCHAR(20) NULL,
   Orderkey        NVARCHAR(20)  NULL,
   SKU             NVARCHAR(20) NULL,
   Notes           NVARCHAR(100) NULL
  )
  
  
  SELECT TOP 1 @c_StorerKey = PH.StorerKey 
  FROM Packheader PH (NOLOCK)
  WHERE PH.loadkey=@c_loadkey
  
   INSERT INTO #TMP_PickOrd79(orderkey,IntVehicle, OHType,
               ExtOrderkey,loadkey, Pickslipno,DeliveryDate, Userdefine01, consigneekey, [State],
               City, Zip, Address1, Address2, Address3, Address4, Company,
               ExternPOKey, Userdefine05, OHSTOP,OrderLineNumber,sku,scolor,
              SKU_SIze, Altsku,PDQty,VAS ) 
                                 
SELECT PD.OrderKey AS Orderkey,O.IntermodalVehicle AS IntermodalVehicle,O.[Type] AS [type],
       O.ExternOrderKey AS externorderkey , O.LoadKey AS loadkey,ph.PickHeaderKey AS Pickslipno,
       CASE WHEN ISNULL(O.UserDefine10,'') = '' THEN CONVERT(NVARCHAR(10),O.DeliveryDate,121) ELSE O.UserDefine10 END AS DeliveryDate,
       O.UserDefine01,O.ConsigneeKey AS Consigneekey,ISNULL(O.C_State,'') AS C_STATE,ISNULL(O.C_City,'') AS C_CITY,
       ISNULL(O.C_Zip,'') AS C_ZIP, ISNULL(O.C_Address1,'') AS C_Address1,ISNULL(O.C_Address2,'') AS C_Address2,ISNULL(O.C_Address3,'') AS C_Address3,
       ISNULL(O.C_Address4,'') AS C_Address4,ISNULL(O.C_Company,'') AS C_Company,O.ExternPOKey AS ExternPOKey,
       O.UserDefine05 AS UserDefine05,O.[Stop] AS [STOP],PD.OrderLineNumber AS OrderlineNumber,
       PD.sku as SKU,'' AS color,
       '' AS [SIZE],
       S.ALTSKU AS ALTSKU,
       SUM(PD.Qty) AS Qty,ISNULL(ODF.Note1, N'') AS VAS
FROM      PICKDETAIL AS PD WITH (NOLOCK) 
INNER JOIN ORDERS AS O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey 
INNER JOIN PickHeader AS PH WITH (NOLOCK) ON O.LoadKey = PH.ExternOrderKey 
INNER JOIN SKU AS s WITH (NOLOCK) ON s.Sku = PD.Sku AND s.StorerKey = PD.Storerkey 
INNER JOIN LOC AS L WITH (NOLOCK) ON PD.LOC = L.LOC LEFT 
OUTER JOIN (SELECT DISTINCT ODF2.StorerKey, ODF2.ParentSKU, ODF2.Orderkey, ODF2.OrderLineNumber, SUBSTRING
            ((SELECT   ', ' + ODF1.Note1
              FROM      OrderDetailRef ODF1(NOLOCK)
              WHERE   ODF1.StorerKey = ODF2.StorerKey AND ODF1.ParentSKU = ODF2.ParentSKU AND 
                      ODF1.Orderkey = ODF2.Orderkey AND 
                      ODF1.OrderLineNumber = ODF2.OrderLineNumber
              ORDER BY ODF1.Rowref FOR XML PATH('')), 2, 1000) AS Note1
              FROM      OrderDetailRef ODF2(NOLOCK)) AS ODF ON PD.StorerKey = ODF.Storerkey AND 
               PD.OrderKey = ODF.Orderkey AND PD.OrderLineNumber = ODF.OrderLineNumber AND PD.Sku = ODF.ParentSKU
WHERE O.loadkey = @c_loadKey
AND L.PickZone = 'BZ'
GROUP BY PD.OrderKey, O.IntermodalVehicle, O.Type, O.ExternOrderKey, O.LoadKey, PH.PickHeaderKey, 
         CASE WHEN ISNULL(O.UserDefine10,'') = '' THEN CONVERT(NVARCHAR(10),O.DeliveryDate,121) ELSE O.UserDefine10 END, O.UserDefine01, 
         O.ConsigneeKey, O.C_State, O.C_City, O.C_Zip, O.C_Address1, 
         O.C_Address2, O.C_Address3, O.C_Address4, O.C_Company, O.ExternPOKey, O.UserDefine05, O.Stop, 
         PD.OrderLineNumber, PD.Sku, s.ALTSKU, ODF.Note1
ORDER BY O.loadkey,PD.OrderKey
 
/*  DECLARE CUR_Labelno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Pickslipno
          ,loadkey
          ,orderkey
         ,sku
         ,OrderLineNumber
   FROM #TMP_PickOrd79 WITH (NOLOCK)
   WHERE loadkey = @c_loadkey

   OPEN CUR_Labelno

   FETCH NEXT FROM CUR_Labelno INTO  @c_PickSlipNo
                                    ,@c_loadkey
                                    ,@c_Ordkey
                                    ,@c_SKU
                                    ,@c_ODLineNumber


   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SET @n_prnqty = 1
      SET @c_ORDRoute = ''
      SET @c_busr7 = ''
      SET @c_VNotes2 = ''
      SET @n_seqno = 1
      SET @c_vas = ''
      SET @c_Category = ''
     -- SET @c_ODLineNumber = ''
       
       --SELECT TOP 1 @c_ODLineNumber = OD.OrderLineNumber
       --FROM ORDERDETAIL OD WITH (NOLOCK)
       --WHERE orderkey=@c_Ordkey
       --AND OD.Sku=@c_SKU
       
       
       INSERT INTO #TEMPVASPOrd79 (pickslipno,loadkey,orderkey,sku,notes)
       SELECT @c_PickSlipNo,@c_loadkey,@c_Ordkey,@c_sku,odr.Note1
       FROM orderdetail od (NOLOCK) 
       join OrderDetailRef AS odr WITH (NOLOCK) ON odr.OrderLineNumber=od.OrderLineNumber AND odr.Orderkey=od.OrderKey
       WHERE od.OrderKey=@c_Ordkey
       AND odr.OrderLineNumber=@c_ODLineNumber
       --AND pd.PickSlipNo=@c_PickSlipNo
       AND od.sku=@c_sku
       
       DECLARE CUR_vas CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT  notes
       FROM #TEMPVASPOrd79
       WHERE loadkey = @c_loadkey
       AND orderkey = @c_Ordkey
       AND sku = @c_sku
       
       OPEN CUR_vas
       
       FETCH NEXT FROM CUR_vas INTO @c_VNote
       WHILE @@FETCH_STATUS <> -1
       BEGIN
         
         
             IF @c_vas = ''
             BEGIN
               SET @c_vas = @c_VNote + CHAR(13)
             END
             ELSE
             BEGIN
               SET @c_vas = @c_vas + @c_VNote + CHAR(13)
             END    
             SET @n_seqno = @n_seqno + 1
      
      FETCH NEXT FROM CUR_vas INTO @c_VNote
      END
      CLOSE CUR_vas
      DEALLOCATE CUR_vas
      

         --UPDATE #TMP_PickOrd79
         --SET VAS = RTRIM(@c_vas)
         --WHERE orderkey = @c_ordkey
         --AND SKU = @c_SKU

   SET @n_lineNo = 1
   
   DELETE FROM #TEMPVASPOrd79          
   SET @n_seqno = 1                     
   
   FETCH NEXT FROM CUR_Labelno INTO @c_PickSlipNo 
                                    ,@c_loadkey
                                    ,@c_Ordkey
                                    ,@c_SKU
                                    ,@c_ODLineNumber
   END
   CLOSE CUR_Labelno
   DEALLOCATE CUR_Labelno */
   
  

   SELECT orderkey,IntVehicle, OHType,
               ExtOrderkey, loadkey,Pickslipno,DeliveryDate, Userdefine01, consigneekey, [State],
               City, Zip, Address1, Address2, Address3, Address4, Company,
               ExternPOKey, Userdefine05, OHSTOP,OrderLineNumber,sku,Altsku,VAS,sum(PDQty) AS PDQty
   FROM #TMP_PickOrd79
   GROUP BY orderkey,IntVehicle, OHType,
               ExtOrderkey,loadkey, Pickslipno,DeliveryDate, Userdefine01, consigneekey, [State],
               City, Zip, Address1, Address2, Address3, Address4, Company,
               ExternPOKey, Userdefine05, OHSTOP,OrderLineNumber,sku,Altsku,
               VAS
   ORDER BY loadkey,orderkey,Orderlinenumber    
   --END
END

GO
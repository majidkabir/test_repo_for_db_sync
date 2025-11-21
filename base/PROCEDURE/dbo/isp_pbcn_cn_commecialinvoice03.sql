SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_PBCN_CN_CommecialInvoice03                     */
/* Creation Date: 13-Mar-2019                                           */
/* Copyright:                                                           */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-8258 - [CN]Fabory-Commercial Invoice                    */
/*                                                                      */
/* Called By: report dw = r_dw_cn_commercialinvoice03                   */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 11-JUN-2019   WLCHOOI  1.0   WMS-9030 Updated Unit price calculation */
/*                                       logic and Price format (WL01)  */
/* 07-JUL-2019   WLCHOOI  1.1   Fixed Wrong price calculation (WL02)    */
/* 20-AUG-2019   CSCHONG  1.2   WMS-10252 revised amout format (CS01)   */
/* 23-OCT-2019   CSCHONG  1.3   WMS-10252 fix amount issue (CS02)       */
/************************************************************************/

CREATE PROC [dbo].[isp_PBCN_CN_CommecialInvoice03](
  @cMBOL_ContrKey NVARCHAR(21)  
) 
AS 
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE @tTempRESULT03 TABLE (
      MBOLKey          NVARCHAR( 20) NULL, 
      ExternOrdKey     NVARCHAR( 30) NULL, 
      DepartureDate    DATETIME  NULL,
      AddDate          DATETIME  NULL, 
      PlaceOfDischarge NVARCHAR( 30) NULL,
      BILLTO_Company   NVARCHAR( 45) NULL,
      BILLTO_Address1  NVARCHAR( 45) NULL, 
      BILLTO_Address2  NVARCHAR( 45) NULL,
      BILLTO_Address3  NVARCHAR( 45) NULL,
      BILLTO_Address4  NVARCHAR( 45) NULL,
      BILLTO_City      NVARCHAR( 45) NULL,
      BILLTO_Zip       NVARCHAR( 18) NULL, 
      BILLTO_State     NVARCHAR( 45) NULL,
      BILLTO_Country   NVARCHAR( 45) NULL,
      OHCity           NVARCHAR( 45) NULL,
      BILLTO_SUSR1     NVARCHAR( 50) NULL,
      StorerKey        NVARCHAR( 15) NULL,
      HSCode           NVARCHAR( 20) NULL,
      SKUDesc          NVARCHAR( 60) NULL,
      COO              NVARCHAR(30)  NULL,
      ShippQty         INT       NULL,
      UnitPrice        DECIMAL(10, 5) NULL,
      UnitPrice1       DECIMAL(10, 5) NULL,            
      OrdKey           NVARCHAR(20) NULL,
      UnitPrice2       DECIMAL(10, 5) NULL,
      MBVessel         NVARCHAR(30) NULL,
      MBVoyageNumber   NVARCHAR(30) NULL,
      SKU              NVARCHAR(20) NULL,
      totalAmt         DECIMAL(10,5) NULL,
      RPTLOGO          NVARCHAR(150) NULL,         --CS01  
      SHOWFIELD        NVARCHAR(10)  NULL          --CS01            
      )
   
   -- Declare variables
   DECLARE
      @b_Debug          INT
     ,@c_mbolkey        NVARCHAR(20)
     ,@c_sku            NVARCHAR(20)
     ,@c_ExtORdkey      NVARCHAR(20)
     ,@c_Coo            NVARCHAR(30)
     ,@n_qty            INT
     ,@n_SumByLot       FLOAT = 0.00
     ,@c_rptlogo        NVARCHAR(150)              --CS01
     --,@n_TotalSUM       DECIMAL(10,2) = 0.00 --WL02 Debug

   SET @b_Debug = 0


   --SET @c_rptlogo = ''
   --SELECT @c_rptlogo = c.notes

     INSERT INTO @tTempRESULT03 (
                  MBOLKey,
                  ExternOrdKey, 
                  DepartureDate,
                  AddDate,
                  PlaceOfDischarge, BILLTO_Company, BILLTO_Address1,
                  BILLTO_Address2, BILLTO_Address3, BILLTO_Address4, BILLTO_City,
                  BILLTO_Zip, BILLTO_State, BILLTO_Country,BILLTO_SUSR1,OHCity,
                  StorerKey, HSCode, SKUDesc, COO, ShippQty,
                  UnitPrice,UnitPrice1,ordkey,UnitPrice2,MBVessel,MBVoyageNumber,sku,totalAmt,RPTLOGO,SHOWFIELD  --CS01 
     )
   
      SELECT 
         cMbolkey          = MBOL.Mbolkey,
         CExtenOrdKey      = MBOLDETAIL.ExternOrderKey,
         dtDepartureDate   = MBOL.DepartureDate,
         dtAddDate         =  MIN(MBOL.AddDate), 
         cPlaceOfDischarge = MBOL.PlaceOfDischarge,
         cBillTo_Company   = ISNULL(MIN(BILLTO.Company),''),
         cBillTo_Address1  = ISNULL(MIN(BILLTO.Address1),''),
         cBillTo_Address2  = ISNULL(MIN(BILLTO.Address2),''),
         cBillTo_Address3  = ISNULL(MIN(BILLTO.Address3),''),
         cBillTo_Address4  = ISNULL(MIN(BILLTO.Address4),''),
         cBillTo_City      = ISNULL(MIN(BILLTO.City),''),
         cBillTo_Zip       = ISNULL(MIN(BILLTO.Zip),''),
         cBillTo_State     = ISNULL(MIN(BILLTO.State),''),
         cBillTo_country   = ISNULL(MIN(BILLTO.Country),''),
         BILLTO_SUSR1      = 'EORI-NUMBER:' + ISNULL(MIN(BILLTO.SUSR1),''),
         OHCity            = ISNULL(MAX(ORDERS.C_City),''), 
         cStorerkey        = ORDERS.StorerKey,
         CHsCode           = ISNULL(SC.Userdefine02,''),
         cSkuDecr          = ISNULL(RTRIM(S.descr),''),
         cCOO              = ISNULL(LOTT.Lottable07,''),
         ShippedQty        = 0, --SUM(PD.qty),                    
         UniPrice          = 0.00, --CASE WHEN ISNUMERIC(C.long) = 1 THEN (S.stdgrosswgt * C.long) ELSE 0.000 END,
         UnitPrice1        = 0.00, --CASE WHEN ISNUMERIC(C1.long) = 1 THEN (S.stdgrosswgt * C1.long) ELSE 0.000 END,
         ordkey            = '',--orders.orderkey
         UnitPrice2        = 0.00, --CASE WHEN ISNUMERIC(LOTT.Lottable08) = 1 THEN CAST(ISNULL(LOTT.Lottable08,'') as numeric(10,5)) ELSE 0.000 END,
         MBVessel          = ISNULL(MBOL.Vessel,''),
         MBVoyageNumber    = ISNULL(MBOL.VoyageNumber,''),
         sku               = PD.SKU,
         totalAmt          = 0,
         rptlogo           = ISNULL(c.notes,''),                            --CS01
         ShowField         = CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END  --CS01
      FROM MBOL WITH (NOLOCK)
      LEFT JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
      LEFT JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
      LEFT JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   --   LEFT JOIN STORER IDSCNSZ WITH (NOLOCK) ON (IDSCNSZ.StorerKey = ORDERS.Facility)
      LEFT JOIN STORER BILLTO WITH (NOLOCK) ON (BILLTO.StorerKey = ORDERS.consigneekey) 
      LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.orderkey = MBOLDETAIL.OrderKey
      JOIN SKU S WITH (NOLOCK) ON S.storerkey = PD.Storerkey AND S.sku =PD.sku 
      JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.LOT = PD.Lot AND LOTT.sku = PD.sku
      LEFT JOIN SKUConfig SC WITH (NOLOCK) ON SC.Storerkey = PD.Storerkey AND SC.sku =PD.sku  
      --LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'Fabprice' and C.storerkey = ORDERDETAIL.Storerkey AND C.code='01'
      --LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname = 'Fabprice' and C1.storerkey = ORDERDETAIL.Storerkey 
      --                                  AND C1.short=LOTT.lottable10
     LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'RPTLOGO' and C.storerkey = ORDERS.Storerkey AND C.long='r_dw_cn_commercialinvoice03'    --CS01 START
     LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (Orders.consigneekey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_cn_commercialinvoice03' AND ISNULL(CLR.Short,'') <> 'N') --CS01 END
      WHERE MBOL.MBOLKey = @cMBOL_ContrKey 
      GROUP BY
         MBOL.MBOLKey,   
         MBOL.DepartureDate,
         MBOL.PlaceOfDischarge,
         MBOLDETAIL.ExternOrderKey,
         ORDERS.StorerKey, 
         ISNULL(SC.Userdefine02,''),
         ISNULL(RTRIM(S.descr),''),
         ISNULL(LOTT.Lottable07,'') 
         --,CASE WHEN ISNUMERIC(LOTT.Lottable08) = 1 THEN CAST(ISNULL(LOTT.Lottable08,'') as numeric(10,5)) ELSE 0.000 END
         --,CASE WHEN ISNUMERIC(C.long) = 1 THEN (S.stdgrosswgt * C.long) ELSE 0.000 END
         --,CASE WHEN ISNUMERIC(C1.long) = 1 THEN (S.stdgrosswgt * C1.long) ELSE 0.000 END
         ,ISNULL(MBOL.Vessel,''),ISNULL(MBOL.VoyageNumber,''),PD.SKU,ISNULL(c.notes,'')           --CS01
        ,CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END  --CS01 


       DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
       SELECT DISTINCT mbolkey,ExternOrdKey,COO,SKU   
       FROM   @tTempRESULT03    
       WHERE mbolkey = @cMBOL_ContrKey  
  
      OPEN CUR_RESULT   
     
      FETCH NEXT FROM CUR_RESULT INTO @c_mbolkey,@c_ExtORdkey,@c_COO,@c_sku    
     
      WHILE @@FETCH_STATUS <> -1  
      BEGIN   

      SET @n_qty = 0
      SET @n_SumByLot = 0.00 --WL01

      SELECT @n_qty = SUM(PD.qty)
      FROM PICKDETAIL PD WITH (NOLOCK) 
        JOIN MBOLDETAIL MD WITH (NOLOCK) 
         ON md.OrderKey = pd.OrderKey
      join orders oh with (nolock) on oh.orderkey = md.orderkey
      JOIN LOTATTRIBUTE lt WITH (NOLOCK) 
         ON lt.StorerKey = pd.Storerkey
            AND lt.Sku = pd.Sku
            AND lt.Lot = pd.Lot
      WHERE md.MbolKey = @c_mbolkey
      AND PD.sku = @c_sku
      AND lt.lottable07 = @c_COO
      AND oh.externorderkey = @c_ExtORdkey

      --WL01 Start
      SELECT @n_SumByLot = @n_SumByLot 
                         + CASE WHEN ISNUMERIC(l.Lottable08) = 1 THEN CAST(ISNULL(l.Lottable08,'') as numeric(10,5) ) * SUM(PD.qty) ELSE 0.000 END
                         + CASE WHEN ISNUMERIC(C1.long) = 1 THEN (S.stdgrosswgt * C1.long * SUM(PD.qty)) ELSE 0.000 END
                         + CASE WHEN ISNUMERIC(C.long) = 1 THEN (S.stdgrosswgt * C.long * SUM(PD.qty)) ELSE 0.000 END
      FROM dbo.PICKDETAIL (NOLOCK) pd
      JOIN dbo.Orders ORD (NOLOCK) ON ORD.OrderKey = PD.OrderKey
      JOIN MBOLDETAIL MD WITH (NOLOCK) ON md.OrderKey = pd.OrderKey
      JOIN dbo.LOTATTRIBUTE (NOLOCK) l ON l.StorerKey = pd.Storerkey and l.lot = pd.lot AND l.Sku = pd.Sku
      JOIN dbo.CODELKUP (NOLOCK) c ON c.Short = l.Lottable10 AND c.LISTNAME = 'FABprice'
      JOIN dbo.CODELKUP (NOLOCK) c1 ON c1.LISTNAME = 'FABprice' AND c1.Code = '01'
      JOIN dbo.SKU (NOLOCK) S ON S.StorerKey = l.StorerKey AND S.Sku = l.Sku
      WHERE l.sku = @c_sku AND l.Lottable07 = @c_COO AND md.MbolKey = @c_mbolkey AND ORD.ExternOrderKey = @c_ExtORdkey
      GROUP BY l.Lottable08, c.Long, c1.Long, S.STDGROSSWGT
      --WL01 End

      --select @n_SumByLot

      UPDATE @tTempRESULT03
      SET ShippQty = @n_qty
         --,totalAmt = (UnitPrice + UnitPrice1 + UnitPrice2) / @n_qty
         ,totalAmt = @n_SumByLot  /@n_Qty   --WL01    --CS01
      WHERE MBOLKey = @c_mbolkey
      AND ExternOrdKey=@c_ExtORdkey
      AND COO = @c_Coo
      AND SKU = @c_sku

      FETCH NEXT FROM CUR_RESULT INTO @c_mbolkey,@c_ExtORdkey,@c_COO,@c_sku 
      END  

   ----WL02 Debug
   --SELECT  @n_TotalSUM = SUM(ShippQty * CAST(totalamt as DECIMAL(10,5)) )
   --FROM @tTempRESULT03

   SET ROWCOUNT 0
   -- Retrieve result

   SELECT 
        MBOLKey,
      ExternOrdKey, 
      DepartureDate,
      AddDate,
      PlaceOfDischarge, 
      BILLTO_Company, 
      BILLTO_Address1,
      BILLTO_Address2, 
      BILLTO_Address3, 
      BILLTO_Address4, 
      BILLTO_City,
      BILLTO_Zip, 
      BILLTO_State, 
      BILLTO_Country, 
      OHCity,
      BILLTO_SUSR1, 
      StorerKey, 
      HSCode, 
      SKUDesc, 
      COO, 
      ShippQty,
      UnitPrice,
      UnitPrice1 ,OrdKey ,UnitPrice2,MBVessel,MBVoyageNumber
      ,sku
      ,totalAmt
      ,CASE WHEN SHOWFIELD = 'N' THEN REPLACE(FORMAT(CAST(FLOOR(totalAmt) AS INT),'###,###,###,###,###,###,##0'),',','.') + ',' +             --WL01  --CS01
       RIGHT(CAST(CAST(ROUND(totalAmt, 5) as DECIMAL(20, 5)) as VARCHAR(20)),5) ELSE CAST(CAST(totalAmt as decimal(10,5)) as nvarchar(30)) END as totalAmt1                   --WL01
      ,CASE WHEN SHOWFIELD = 'N' THEN REPLACE(FORMAT(CAST(FLOOR(ShippQty * totalAmt) AS INT),'####################0'),',','.') + ',' +  --WL01
       --RIGHT(CAST(CAST(ROUND(ShippQty * totalAmt, 5) as DECIMAL(20, 5)) as VARCHAR(20)),2) as QtyxAmt          --WL01
       RIGHT(CAST(CAST(ROUND(ShippQty * totalAmt,2) AS DECIMAL(20,2)) AS NVARCHAR(30)),2) ELSE CAST(CAST((ShippQty * totalAmt) as decimal(10,2)) as nvarchar(30)) END as QtyxAmt    --WL02  --CS01 --CS02
      ,SUBSTRING(REPLACE(FORMAT(CAST(FLOOR(ShippQty) AS INT),'###,###,###,###,###,###,##0'),',','.') + ',' +  --WL01
       RIGHT(CAST(CAST(ROUND(ShippQty, 5) as DECIMAL(20, 5)) as VARCHAR(20)),2),1,CHARINDEX(',',REPLACE(FORMAT(CAST(FLOOR(ShippQty) AS INT),'###,###,###,###,###,###,##0'),',','.') + ',' +             --WL01
       RIGHT(CAST(CAST(ROUND(ShippQty, 5) as INT) as VARCHAR(20)),2))-1) as ShippQty1                   --WL01
    --  ,@n_TotalSUM --WL02 Debug
       , RPTlogo       --CS01
      , SHOWFIELD     --CS01
   FROM @tTempRESULT03
   ORDER BY  HSCode, 
             SKUDesc,
             sku, 
             COO

END


GO
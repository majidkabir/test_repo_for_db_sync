SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: nsp_JRPT_LEGO_TRANSPORT_CHARGE						*/
/* Creation Date: 03-03-2021											*/
/* Copyright: LF Logistics												*/
/* Written by: Chong Hwang Chua											*/
/*																		*/
/* Purpose: For Lego Transport Charge in Jreport						*/
/*			https://jiralfl.atlassian.net/browse/WMS-16474				*/
/*                                                                      */
/* Called By: Jreport                                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author		Ver.	Purposes                           	*/
/* 2021-3-17	BLLIM		1.1		Exclude parcel shipment type		*/
/* 2021-4-19	BLLIM		1.2		Added StorerKey join (WMS-16853)	*/
/* 2023-1-4     BLLIM		1.3		Fix InvoiceRef# Issie (WMS-21487) 	*/
/* 2023-1-10	Nicholas	1.4		to cater for Orders.InvoiceNo	    */
/************************************************************************/

-- Test: EXEC BI.nsp_JRPT_LEGO_TRANSPORT_CHARGE '', '2021-02-22';
CREATE   PROC  [BI].[nsp_JRPT_LEGO_TRANSPORT_CHARGE]
   @c_Storerkey    NVARCHAR(20),
   @dt_Date        DATETIME
AS
BEGIN
   SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

DECLARE @c_Currency      NVARCHAR(20),
        @dt_RetrieveDT   DateTime,
        @dt_RetrieveFrDT DateTime,
        @dt_RetrieveToDT DateTime,
        @n_DayofWeek     Integer,
        @c_year          NVARCHAR(20),
        @c_weekno        NVARCHAR(20),
        @c_invoice       NVARCHAR(30),
        @c_MBolkey       NVARCHAR(20),
        @c_DeliveryNo    NVARCHAR(40),
        @c_NewDeliveryNo NVARCHAR(40),
        @c_Orderkey      NVARCHAR(20),
        @c_ShipmentNo    NVARCHAR(20),
        @c_ContainerKey  NVARCHAR(20),
        @c_ConsigneeKey  NVARCHAR(20),
        @c_Address       NVARCHAR(800),
        @c_PostalCode    NVARCHAR(40),
        @c_PlatformName  NVARCHAR(400),
        @d_No_of_Pallets DECIMAL(12,6),
        @d_Tot_Vol       DECIMAL(12,6),
        @d_Tot_GrossWgt  DECIMAL(12,6),
        @n_NoFullCA      Integer,
        @n_NoLooseCA     Integer,
        @d_FRT_Amt       DECIMAL(12,6),
        @d_Fuel_Sur      DECIMAL(12,6),
        @d_VAT           DECIMAL(12,6),
		@n_Pos           Integer,
        @dt_ShipDate     DateTime,
		@cInvoiceNo			NVARCHAR(40), --Added 2023-1-10	Nicholas,
		@cFinalInvoiceNo	NVARCHAR(40) --Added 2023-1-10	Nicholas

   SET @dt_RetrieveDT = @dt_Date
   IF @dt_Date is NULL
   BEGIN
      SELECT @dt_RetrieveDT = Convert(date, getdate())
   END

   SELECT @c_year = DATEPART(yyyy,@dt_RetrieveDT)
--print @c_year

   SELECT @c_weekno = DATEPART(ww, @dt_RetrieveDT)
--print @c_weekno

--v1.3
--   IF DATEPART(dw, @c_year + '-01-01') <> 2 --(Monday)
   IF DATEPART(dw, @c_year + '-01-01') > 2 --(Monday)
   BEGIN
      SET @c_weekno = @c_weekno - 1
      print @c_weekno
      IF cast(@c_weekno as Int) < 1
      BEGIN
         SET @c_year = @c_year - 1
         SET @c_weekno = DATEPART(ww, @c_year + '-12-31')
--v1.3
--         IF DATEPART(dw, @c_year + '-01-01') <> 2
         IF DATEPART(dw, @c_year + '-01-01') > 2
         BEGIN
            Set @c_weekno = @c_weekno - 1
         END
      END
   END

   IF Cast(@c_weekno as Int) < 10
   BEGIN
      Set @c_weekno = '0' + @c_weekno
   END

   SELECT  @c_invoice = 'LFLT' + Right(@c_year,2) + @c_weekno + Long + '01'
   FROM CODELKUP WITH (NOLOCK)
   WHERE Listname = 'CUSTPARAM' 
   AND Storerkey = 'LEGO' 
   AND Code = 'FMS_INV_CODE'

   SET @n_DayofWeek = DATEPART(dw, @dt_RetrieveDT)
   IF @n_DayofWeek = 1 --Sunday
   BEGIN
      SET @dt_RetrieveFrDT = DateAdd(d, -13, @dt_RetrieveDT)
      SET @dt_RetrieveToDT = DateAdd(d, -6, @dt_RetrieveDT)
   END
   ELSE
   BEGIN
      SET @dt_RetrieveFrDT = DateAdd(d, -(7 + @n_DayofWeek -2), @dt_RetrieveDT)
      SET @dt_RetrieveToDT = DateAdd(d, -(0 + @n_DayofWeek -2), @dt_RetrieveDT)
--      SET @dt_RetrieveToDT = DateAdd(d, -1, @dt_RetrieveDT)
   END

   IF OBJECT_ID('tempdb..#TEMP_FRTCHARGE_MBOLKEY','u') IS NOT NULL  
      DROP TABLE #TEMP_FRTCHARGE_MBOLKEY
    CREATE TABLE #TEMP_FRTCHARGE_MBOLKEY   
    ( MBOLKEY       NVARCHAR(20),
      ShipmentNo    NVARCHAR(100),
      ShipDate      DateTime
     )

   IF OBJECT_ID('tempdb..#TEMP_FRTCHARGE','u') IS NOT NULL  
      DROP TABLE #TEMP_FRTCHARGE
    CREATE TABLE #TEMP_FRTCHARGE   
    ( InvoiceNo     NVARCHAR(40),  
      Inv_Curr      NVARCHAR(40),    
      MBolkey       NVARCHAR(40),    
      DONo          NVARCHAR(40),      
      NewDONo       NVARCHAR(40),      
      Orderkey      NVARCHAR(40),      
      ShipmentNo    NVARCHAR(40),      
      ContainerKey  NVARCHAR(40),      
      ConsigneeKey  NVARCHAR(40),      
      Address       NVARCHAR(800),      
      PostalCode	NVARCHAR(40),      
      NoofPallet    Decimal(12,8),    
      Tot_Vol       Decimal(12,8),    
      Tot_GrWgt     Decimal(12,8),    
      NoofFullCA    INT,    
      NoofLooseCA   INT,    
      Frt_Amt       Decimal(12,8),    
      SurCharge_Amt Decimal(12,8),    
      VAT_Amt       Decimal(12,8),
      ShipDate      DateTime
     )
    
   SELECT @c_Currency = Long
   FROM CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'CUSTPARAM'
   AND STORERKEY = 'LEGO'
   AND CODE = 'FMS_EDI'
   AND CODE2 = 'INV_CUR'

   INSERT INTO #TEMP_FRTCHARGE_MBOLKEY
   SELECT DISTINCT M.MbolKey, ExternOrdersKey, M.ShipDate 
   FROM MBOL M WITH (NOLOCK), MBOLDETAIL MD WITH (NOLOCK), ORDERS O WITH (NOLOCK), ExternOrders EXO WITH (NOLOCK), STORER ST WITH (NOLOCK)
   WHERE M.MbolKey = MD.MBOLKey
   AND MD.MbolKey = O.MBOLKey
   AND EXO.ExternOrderKey = M.MbolKey
   AND EXO.OrderKey IN ('C888888888','C999999999')
   AND O.StorerKey = 'LEGO'
   AND M.Status = '9'
   AND M.ShipDate >= @dt_RetrieveFrDT
   AND M.ShipDate < @dt_RetrieveToDT
   AND O.Storerkey = ST.Storerkey						--Added 2021-04-19 cch
   AND O.C_Country = ST.Country
   AND NOT EXISTS (SELECT 1 FROM CODELKUP CLK           --Added 2021-03-11
                   WHERE CLK.LISTNAME = 'CUSTPARAM'
                   AND CLK.CODE = 'FMS_EXCLTYPE'
                   AND CLK.STORERKEY = O.STORERKEY
                   AND CLK.CODE2 = O.IntermodalVehicle)
--   AND M.UserDefine07 >= @dt_RetrieveFrDT
--   AND M.UserDefine07 < @dt_RetrieveToDT

   DECLARE CUR_EXTERNORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT EXO1.Userdefine10, O.ExternOrderKey, IsNull(EXO1.Userdefine09,''), 
   EXO1.OrderKey, EXO1.ExternOrderKey, IsNull(EXO1.Source,''), O.ConsigneeKey, 
   Address = CASE O.C_Company WHEN '' THEN '' ELSE O.C_Company + ' ' END + CASE O.C_Address1  WHEN '' THEN '' ELSE O.C_Address1 + ' ' END + CASE O.C_Address2  WHEN '' THEN '' ELSE O.C_Address2 + ' ' END + CASE O.C_City WHEN '' THEN '' ELSE O.C_City + ' ' END + CASE O.C_State WHEN '' THEN '' ELSE O.C_State END, 
   PostalCode = O.C_Zip, PlatformName, Cast(EXO1.Userdefine01 AS Decimal(12,6)), IsNull(CAST(EXO1.Userdefine02 AS INT),0), 
   IsNull(CAST(EXO1.Userdefine03 AS INT),0), Cast(EXO1.Userdefine06 AS Decimal(10,2)),
   Cast(EXO1.Userdefine07 AS Decimal(10,2)), Cast(EXO1.Userdefine08 AS Decimal(10,2)), MBH.ShipDate, O.InvoiceNo --Added 2023-1-10	Nicholas
   FROM ExternOrders EXO1 WITH (NOLOCK), ORDERS O WITH (NOLOCK), #TEMP_FRTCHARGE_MBOLKEY MBH
   WHERE EXO1.OrderKey = O.OrderKey
   AND EXO1.ExternOrderKey = MBH.ShipmentNo
   Order by MBH.ShipmentNo, O.ConsigneeKey, EXO1.OrderKey

   OPEN CUR_EXTERNORDERS   
     
   FETCH NEXT FROM CUR_EXTERNORDERS INTO @c_MBolkey, @c_DeliveryNo,@c_NewDeliveryNo, @c_Orderkey, @c_ShipmentNo, @c_ContainerKey,@c_ConsigneeKey, @c_Address,
      @c_PostalCode, @c_PlatformName,@d_Tot_Vol, @n_NoFullCA, @n_NoLooseCA, @d_FRT_Amt,@d_Fuel_Sur, @d_VAT,@dt_ShipDate, @cInvoiceNo  --Added 2023-1-10	Nicholas
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN 

      SET @d_Tot_GrossWgt = 0
      SET @d_No_of_Pallets = 0
      SET @n_Pos = PATINDEX('%|%',@c_PlatformName)
	  IF @n_Pos > 0
      BEGIN
         SET @d_Tot_GrossWgt = Cast(SubString(@c_PlatformName, 1, @n_Pos -1) AS Decimal(12,6))
         SET @c_PlatformName = SubString(@c_PlatformName, @n_Pos + 1, 200)
         SET @n_Pos = PATINDEX('%|%',@c_PlatformName)
         IF @n_Pos > 0
         BEGIN
            SET @c_PlatformName = SubString(@c_PlatformName, @n_Pos + 1, 200)
            SET @d_No_of_Pallets = Cast(@c_PlatformName AS Decimal(12,6))
         END
      END

	  --Added 2023-1-10	Nicholas
	  Select @cFinalInvoiceNo = @c_invoice

	  If @cInvoiceNo <> ''
		Select @cFinalInvoiceNo = @cInvoiceNo

	  --Added 2023-1-10	Nicholas, change @c_invoice to @cFinalInvoiceNo
      INSERT INTO #TEMP_FRTCHARGE ( InvoiceNo, Inv_Curr, MBolkey, DONo, NewDONo, Orderkey, ShipmentNo, ContainerKey, ConsigneeKey,
                                   Address, PostalCode, NoofPallet, Tot_Vol, Tot_GrWgt, NoofFullCA, NoofLooseCA, Frt_Amt, SurCharge_Amt, VAT_Amt,ShipDate)
      VALUES (@cFinalInvoiceNo, @c_Currency,@c_MBolkey,@c_DeliveryNo,@c_NewDeliveryNo, @c_Orderkey, @c_ShipmentNo, @c_ContainerKey,@c_ConsigneeKey, 
              @c_Address,@c_PostalCode, @d_No_of_Pallets,@d_Tot_Vol,@d_Tot_GrossWgt, @n_NoFullCA, @n_NoLooseCA, @d_FRT_Amt,@d_Fuel_Sur, @d_VAT,@dt_ShipDate)

      FETCH NEXT FROM CUR_EXTERNORDERS INTO @c_MBolkey, @c_DeliveryNo,@c_NewDeliveryNo, @c_Orderkey, @c_ShipmentNo, @c_ContainerKey,@c_ConsigneeKey, @c_Address,
         @c_PostalCode, @c_PlatformName,@d_Tot_Vol, @n_NoFullCA, @n_NoLooseCA, @d_FRT_Amt,@d_Fuel_Sur, @d_VAT,@dt_ShipDate, @cInvoiceNo --Added 2023-1-10	Nicholas
   END  
   CLOSE CUR_EXTERNORDERS  
   DEALLOCATE CUR_EXTERNORDERS     

   SELECT InvoiceNo, Inv_Curr, MBolkey, DONo, NewDONo, Orderkey, ShipmentNo, ContainerKey, ConsigneeKey,
          Address, PostalCode, NoofPallet, Tot_Vol, Tot_GrWgt, NoofFullCA, NoofLooseCA, Frt_Amt, SurCharge_Amt, VAT_Amt,ShipDate
   FROM #TEMP_FRTCHARGE
   ORDER BY InvoiceNo, MBolkey, ConsigneeKey, Orderkey

   IF OBJECT_ID('tempdb..#TEMP_FRTCHARGE_MBOLKEY','u') IS NOT NULL  
      DROP Table #TEMP_FRTCHARGE_MBOLKEY  
   IF OBJECT_ID('tempdb..#TEMP_FRTCHARGE','u') IS NOT NULL  
      DROP Table #TEMP_FRTCHARGE

END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_hk_LEGO0008_LEGO_TransportChangeReport          */
/* Creation Date: 26-08-2021                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Bonnie Wan                                               */
/*                                                                      */
/* Purpose: For Lego Transport Charge Report in LogiReport              */
/*                                                                      */
/* Called By: LogiReport                                                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author       Ver.   Purposes                            */
/* 26/08/2021   Bonnie Wan   1.0    Created                             */
/* 26/10/2021   Bonnie Wan   1.1    Add Order.DeliveryDate,             */
/*                                  Edit PostalCode mapping             */
/* 01/12/2021   Bonnie Wan   1.2    Modify and deploy the script https://jiralfl.atlassian.net/browse/WMS-18491 */
/* 07/02/2023   Bonnie Wan   2.0    Modify Weekno logic (LFI-8313)      */
/************************************************************************/

-- Test: EXEC BI.isp_hk_LEGO0008_LEGO_TransportChangeReport 'LEGO', '2021-11-25';
CREATE   PROC [BI].[isp_hk_LEGO0008_LEGO_TransportChangeReport]
    @c_Storerkey NVARCHAR(20)
  , @dt_Date     DATETIME
AS
BEGIN
    SET NOCOUNT ON; -- keeps the output generated to a minimum
    SET ANSI_NULLS OFF;
    SET QUOTED_IDENTIFIER OFF;
    SET CONCAT_NULL_YIELDS_NULL OFF;

    DECLARE @c_Currency NVARCHAR(20)
            , @dt_RetrieveDT DATETIME
            , @dt_RetrieveFrDT DATETIME
            , @dt_RetrieveToDT DATETIME
            , @n_DayofWeek INTEGER
            , @c_year NVARCHAR(20)
            , @c_weekno NVARCHAR(20)
            , @c_invoice NVARCHAR(30)
            , @c_MBolkey NVARCHAR(20)
            , @c_DeliveryNo NVARCHAR(40)
            , @c_NewDeliveryNo NVARCHAR(40)
            , @c_Orderkey NVARCHAR(20)
            , @c_ShipmentNo NVARCHAR(20)
            , @c_ContainerKey NVARCHAR(20)
            , @c_ConsigneeKey NVARCHAR(20)
            , @c_Address NVARCHAR(800)
            , @c_PostalCode NVARCHAR(40)
            , @c_PlatformName NVARCHAR(400)
            , @d_No_of_Pallets DECIMAL(12, 6)
            , @d_Tot_Vol DECIMAL(12, 6)
            , @d_Tot_GrossWgt DECIMAL(12, 6)
            , @n_NoFullCA INTEGER
            , @n_NoLooseCA INTEGER
            , @d_FRT_Amt DECIMAL(12, 6)
            , @d_Fuel_Sur DECIMAL(12, 6)
            , @d_VAT DECIMAL(12, 6)
            , @n_Pos INTEGER
            , @dt_ShipDate DATETIME
            , @c_C_Company NVARCHAR(200)
            , @dt_DeliveryDate DATETIME   --v1.1;

   IF ISNULL(@dt_Date , '') = ''
      SET @dt_Date  = GETDATE()
   IF ISNULL(@c_Storerkey, '') = ''
      SET @c_Storerkey = ''

   DECLARE @nRowCnt INT = 0
         , @Proc      NVARCHAR(128) = 'isp_hk_LEGO0008_LEGO_TransportChangeReport'
         , @cParamOut NVARCHAR(4000)= ''
         , @cParamIn  NVARCHAR(4000)= '{ "PARAM_c_Storerkey":"'+@c_Storerkey+'"'
                                    + '"PARAM_dt_Date":"'+CONVERT(NVARCHAR(19),@dt_Date,121)+'"'
                                    + ' }'

   DECLARE @tVarLogId TABLE (LogId INT);
   INSERT dbo.ExecutionLog (ClientId, SP, ParamIn) OUTPUT INSERTED.LogId INTO @tVarLogId VALUES (@c_Storerkey, @Proc, @cParamIn);

	DECLARE @Stmt NVARCHAR(MAX) = '' -- for storing dynamic SQL Statement

        SET @dt_RetrieveDT = @dt_Date;
        IF @dt_Date IS NULL
            BEGIN
                SELECT @dt_RetrieveDT = CONVERT(DATE, GETDATE());
            END;
        SELECT @c_year = DATEPART(yyyy, @dt_RetrieveDT); --print @c_year
        SELECT @c_weekno = DATEPART(ww, @dt_RetrieveDT); --print @c_weekno

        IF DATEPART(dw, @c_year + '-01-01') > 2 --(Monday)
            BEGIN
                SET @c_weekno = @c_weekno - 1;
                PRINT @c_weekno;
                IF CAST(@c_weekno AS INT) < 1
                    BEGIN
                        SET @c_year = @c_year - 1;
                        SET @c_weekno = DATEPART(ww, @c_year + '-12-31');
                        IF DATEPART(dw, @c_year + '-01-01') > 2
                            BEGIN
                                SET @c_weekno = @c_weekno - 1;
                            END;
                    END;
            END;

        IF CAST(@c_weekno AS INT) < 10
            BEGIN
                SET @c_weekno = '0' + @c_weekno;
            END;
        SELECT @c_invoice = 'LFLT' + RIGHT(@c_year, 2) + @c_weekno + Long + '01'
        FROM bi.V_CODELKUP WITH(NOLOCK)
        WHERE Listname = 'CUSTPARAM'
              AND Storerkey = @c_Storerkey
              AND Code = 'FMS_INV_CODE';
        SET @n_DayofWeek = DATEPART(dw, @dt_RetrieveDT);

        IF @n_DayofWeek = 1 --Sunday
            BEGIN
                SET @dt_RetrieveFrDT = DATEADD(d, -13, @dt_RetrieveDT);
                SET @dt_RetrieveToDT = DATEADD(d, -6, @dt_RetrieveDT);
            END;
            ELSE
            BEGIN
                SET @dt_RetrieveFrDT = DATEADD(d, -(7 + @n_DayofWeek - 2), @dt_RetrieveDT);
                SET @dt_RetrieveToDT = DATEADD(d, -(0 + @n_DayofWeek - 2), @dt_RetrieveDT);
                --      SET @dt_RetrieveToDT = DateAdd(d, -1, @dt_RetrieveDT)
            END;

        IF OBJECT_ID('tempdb..#TEMP_FRTCHARGE_MBOLKEY', 'u') IS NOT NULL
            DROP TABLE #TEMP_FRTCHARGE_MBOLKEY;
            CREATE TABLE #TEMP_FRTCHARGE_MBOLKEY
                        (MBOLKEY    NVARCHAR(20)
                       , ShipmentNo NVARCHAR(100)
                       , ShipDate   DATETIME
                        );
        IF OBJECT_ID('tempdb..#TEMP_FRTCHARGE', 'u') IS NOT NULL
            DROP TABLE #TEMP_FRTCHARGE;
            CREATE TABLE #TEMP_FRTCHARGE
              (InvoiceNo     NVARCHAR(40)
             , Inv_Curr      NVARCHAR(40)
             , MBolkey       NVARCHAR(40)
             , DONo          NVARCHAR(40)
             , NewDONo       NVARCHAR(40)
             , Orderkey      NVARCHAR(40)
             , ShipmentNo    NVARCHAR(40)
             , ContainerKey  NVARCHAR(40)
             , ConsigneeKey  NVARCHAR(40)
             , Address       NVARCHAR(800)
             , PostalCode    NVARCHAR(40)
             , NoofPallet    DECIMAL(12, 8)
             , Tot_Vol       DECIMAL(12, 8)
             , Tot_GrWgt     DECIMAL(12, 8)
             , NoofFullCA    INT
             , NoofLooseCA   INT
             , Frt_Amt       DECIMAL(12, 8)
             , SurCharge_Amt DECIMAL(12, 8)
             , VAT_Amt       DECIMAL(12, 8)
             , ShipDate      DATETIME
             , C_Company     NVARCHAR(200)
             , DeliveryDate  DATETIME    --v1.1
              );
        SELECT @c_Currency = Long
        FROM bi.V_CODELKUP WITH(NOLOCK)
        WHERE LISTNAME = 'CUSTPARAM'
              AND STORERKEY = @c_Storerkey
              AND CODE = 'FMS_EDI'
              AND CODE2 = 'INV_CUR';

        INSERT INTO #TEMP_FRTCHARGE_MBOLKEY
               SELECT DISTINCT
                      M.MbolKey
                    , ExternOrdersKey
                    , M.ShipDate
               FROM bi.V_MBOL M WITH(NOLOCK)
               JOIN bi.V_MBOLDETAIL MD WITH(NOLOCK) ON M.MbolKey = MD.MBOLKey
               JOIN bi.V_ORDERS O WITH(NOLOCK) ON MD.MbolKey = O.MBOLKey
               JOIN bi.V_ExternOrders EXO WITH(NOLOCK) ON EXO.ExternOrderKey = M.MbolKey AND EXO.OrderKey IN('C888888888', 'C999999999')
                  --, bi.V_STORER ST WITH(NOLOCK)
               WHERE  O.StorerKey = @c_Storerkey
                     AND M.STATUS = '9'
                     AND M.ShipDate >= @dt_RetrieveFrDT
                     AND M.ShipDate < @dt_RetrieveToDT
                     AND O.C_Country IN ('HK', 'MO')
                     --= ST.Country
                     ;

        DECLARE CUR_EXTERNORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY
        FOR SELECT EXO1.Userdefine10
                 , O.ExternOrderKey
                 , ISNULL(EXO1.Userdefine09, '')
                 , EXO1.OrderKey
                 , EXO1.ExternOrderKey
                 , ISNULL(EXO1.Source, '')
                 , O.ConsigneeKey
                 , Address = CASE O.C_Company
                                 WHEN ''
                                 THEN ''
                                 ELSE O.C_Company + ' '
                             END + CASE O.C_Address1
                                       WHEN ''
                                       THEN ''
                                       ELSE O.C_Address1 + ' '
                                   END + CASE O.C_Address2
                                             WHEN ''
                                             THEN ''
                                             ELSE O.C_Address2 + ' '
                                         END + CASE O.C_City
                                                   WHEN ''
                                                   THEN ''
                                                   ELSE O.C_City + ' '
                                               END + CASE O.C_State
                                                         WHEN ''
                                                         THEN ''
                                                         ELSE O.C_State
                                                     END
                 , PostalCode = O.C_Country        --v1.1
                 , PlatformName
                 , CAST(EXO1.Userdefine01 AS DECIMAL(12, 6))
                 , ISNULL(CAST(EXO1.Userdefine02 AS INT), 0)
                 , ISNULL(CAST(EXO1.Userdefine03 AS INT), 0)
                 , CAST(EXO1.Userdefine06 AS DECIMAL(10, 2))
                 , CAST(EXO1.Userdefine07 AS DECIMAL(10, 2))
                 , CAST(EXO1.Userdefine08 AS DECIMAL(10, 2))
                 , MBH.ShipDate
                 , O.C_Company
                 , O.DeliveryDate     --v1.1
            FROM bi.V_ExternOrders EXO1 WITH(NOLOCK)
            JOIN bi.V_ORDERS O WITH(NOLOCK) ON EXO1.OrderKey = O.OrderKey
            JOIN #TEMP_FRTCHARGE_MBOLKEY MBH ON EXO1.ExternOrderKey = MBH.ShipmentNo 
            ORDER BY MBH.ShipmentNo
                   , O.ConsigneeKey
                   , EXO1.OrderKey;

        OPEN CUR_EXTERNORDERS;
        FETCH NEXT FROM CUR_EXTERNORDERS INTO @c_MBolkey, @c_DeliveryNo, @c_NewDeliveryNo, @c_Orderkey, @c_ShipmentNo, @c_ContainerKey, @c_ConsigneeKey, @c_Address, @c_PostalCode, @c_PlatformName, @d_Tot_Vol, @n_NoFullCA, @n_NoLooseCA, @d_FRT_Amt, @d_Fuel_Sur, @d_VAT, @dt_ShipDate, @c_C_Company, @dt_DeliveryDate;

        WHILE @@FETCH_STATUS <> -1
            BEGIN
                SET @d_Tot_GrossWgt = 0;
                SET @d_No_of_Pallets = 0;
                SET @n_Pos = PATINDEX('%|%', @c_PlatformName);
                IF @n_Pos > 0
                    BEGIN
                        SET @d_Tot_GrossWgt = CAST(SUBSTRING(@c_PlatformName, 1, @n_Pos - 1) AS DECIMAL(12, 6));
                        SET @c_PlatformName = SUBSTRING(@c_PlatformName, @n_Pos + 1, 200);
                        SET @n_Pos = PATINDEX('%|%', @c_PlatformName);
                        IF @n_Pos > 0
                            BEGIN
                                SET @c_PlatformName = SUBSTRING(@c_PlatformName, @n_Pos + 1, 200);
                                SET @d_No_of_Pallets = TRY_CONVERT(DECIMAL(12, 6), @c_PlatformName);
                            END;
                    END;
                INSERT INTO #TEMP_FRTCHARGE
                 (InvoiceNo
                , Inv_Curr
                , MBolkey
                , DONo
                , NewDONo
                , Orderkey
                , ShipmentNo
                , ContainerKey
                , ConsigneeKey
                , Address
                , PostalCode
                , NoofPallet
                , Tot_Vol
                , Tot_GrWgt
                , NoofFullCA
                , NoofLooseCA
                , Frt_Amt
                , SurCharge_Amt
                , VAT_Amt
                , ShipDate
                , C_Company
                , DeliveryDate    --v1.1
                 )
                VALUES
                 (@c_invoice
                , @c_Currency
                , @c_MBolkey
                , @c_DeliveryNo
                , @c_NewDeliveryNo
                , @c_Orderkey
                , @c_ShipmentNo
                , @c_ContainerKey
                , @c_ConsigneeKey
                , @c_Address
                , @c_PostalCode
                , @d_No_of_Pallets
                , @d_Tot_Vol
                , @d_Tot_GrossWgt
                , @n_NoFullCA
                , @n_NoLooseCA
                , @d_FRT_Amt
                , @d_Fuel_Sur
                , @d_VAT
                , @dt_ShipDate
                , @c_C_Company
                , @dt_DeliveryDate    --v1.1
                 );
                FETCH NEXT FROM CUR_EXTERNORDERS INTO @c_MBolkey, @c_DeliveryNo, @c_NewDeliveryNo, @c_Orderkey, @c_ShipmentNo, @c_ContainerKey, @c_ConsigneeKey, @c_Address
                , @c_PostalCode, @c_PlatformName, @d_Tot_Vol, @n_NoFullCA, @n_NoLooseCA, @d_FRT_Amt, @d_Fuel_Sur, @d_VAT, @dt_ShipDate, @c_C_Company, @dt_DeliveryDate;
            END;
        CLOSE CUR_EXTERNORDERS;

        DEALLOCATE CUR_EXTERNORDERS;
        SELECT [LEGO0008_010_InvoiceNo]     = InvoiceNo
             , [LEGO0008_020_Mbolkey]       = MBolkey
             , [LEGO0008_030_ShipDate]      = ShipDate
             , [LEGO0008_035_DeliveryDate]  = DeliveryDate    --v1.1
             , [LEGO0008_040_ConsigneeKey]  = ConsigneeKey
             , [LEGO0008_050_ContainerKey]  = ContainerKey
             , [LEGO0008_060_ShipmentNo]    = ShipmentNo
             , [LEGO0008_070_Orderkey]      = Orderkey
             , [LEGO0008_080_DONo]          = DONo
             , [LEGO0008_090_NewDONo]       = NewDONo
             , [LEGO0008_095_C_Company]     = C_Company
             , [LEGO0008_100_Address]       = Address
             , [LEGO0008_110_PostalCode]    = PostalCode
             , [LEGO0008_120_NoofPallet]    = NoofPallet
             , [LEGO0008_130_NoofFullCA]    = NoofFullCA
             , [LEGO0008_140_NoofLooseCA]   = NoofLooseCA
             , [LEGO0008_150_Tot_Vol]       = Tot_Vol
             , [LEGO0008_160_Tot_GrWgt]     = Tot_GrWgt
             , [LEGO0008_170_Inv_Curr]      = Inv_Curr
             , [LEGO0008_180_Frt_Amt]       = Frt_Amt
             , [LEGO0008_190_SurCharge_Amt] = SurCharge_Amt
             , [LEGO0008_200_VAT_Amt]       = VAT_Amt
        FROM #TEMP_FRTCHARGE
        ORDER BY InvoiceNo
               , MBolkey
               , ConsigneeKey
               , Orderkey;
        IF OBJECT_ID('tempdb..#TEMP_FRTCHARGE_MBOLKEY', 'u') IS NOT NULL
            DROP TABLE #TEMP_FRTCHARGE_MBOLKEY;
        IF OBJECT_ID('tempdb..#TEMP_FRTCHARGE', 'u') IS NOT NULL
            DROP TABLE #TEMP_FRTCHARGE;

	SET @nRowCnt = @@ROWCOUNT;

   SET @cParamOut = '{ "Stmt": "'+@Stmt+'" }'; -- for dynamic SQL only
   UPDATE dbo.ExecutionLog SET TimeEnd = GETDATE(), RowCnt = @nRowCnt, ParamOut = @cParamOut
   WHERE LogId = (SELECT TOP 1 LogId FROM @tVarLogId);


END

GO
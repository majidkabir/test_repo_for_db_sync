SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: BarTender Filter by ShipperKey                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2019-08-01 1.0  WLCHOOI    Created (WMS-10039)                             */
/* 2020-01-17 1.1  CSCHONG    WMS-11764 revised field mapping (CS01)          */
/* 2020-10-27 1.2  CSCHONG    Performance tunning (CS02)                      */
/* 2021-04-02 1.3  CSCHONG    WMS-16024 PB-Standardize TrackingNo (CS03)      */
/* 2021-06-03 1.4  CSCHONG    WMS-17157 revised field logic (CS04)            */
/* 2022-01-12 1.5  KuanYeeC   Change F.ADDRESS1 to 3, and Cater 80CH (KY01)   */
/* 2022-10-12 1.6  Mingle		WMS-20916 Update col25,26,27,31,32(ML01)        */
/******************************************************************************/

CREATE PROC [dbo].[isp_BT_Bartender_Shipper_Label_VIP]
(  @c_Sparm1            NVARCHAR(250),
   @c_Sparm2            NVARCHAR(250),
   @c_Sparm3            NVARCHAR(250),
   @c_Sparm4            NVARCHAR(250),
   @c_Sparm5            NVARCHAR(250),
   @c_Sparm6            NVARCHAR(250),
   @c_Sparm7            NVARCHAR(250),
   @c_Sparm8            NVARCHAR(250),
   @c_Sparm9            NVARCHAR(250),
   @c_Sparm10           NVARCHAR(250),
   @b_debug             INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_OrderKey          NVARCHAR(10),
           @c_ExternOrderKey    NVARCHAR(50),
           @c_Deliverydate      DATETIME,
           @c_ConsigneeKey      NVARCHAR(15),
           @c_Company           NVARCHAR(45),
           @C_Address1          NVARCHAR(45),
           @C_Address2          NVARCHAR(45),
           @C_Address3          NVARCHAR(45),
           @C_Address4          NVARCHAR(45),
           @C_BuyerPO           NVARCHAR(20),
           @C_notes2            NVARCHAR(4000),
           @c_SKU               NVARCHAR(20),
           @c_PackKey           NVARCHAR(10),
           @c_UOM               NVARCHAR(10),
           @C_PHeaderKey        NVARCHAR(18),
           @C_SODestination     NVARCHAR(30),
           @n_RowNo             INT,
           @n_SumPickDetQty     INT,
           @n_SumUnitPrice      INT,
           @c_SQL               NVARCHAR(4000),
           @c_SQLSORT           NVARCHAR(4000),
           @c_SQLJOIN           NVARCHAR(4000),
           @c_Udef04            NVARCHAR(80),
           @c_TrackingNo        NVARCHAR(20),
           @n_RowRef            INT,
           @c_CLong             NVARCHAR(250),
           @c_ORDAdd            NVARCHAR(150),
           @n_TTLPickQTY        INT,
           @c_ShipperKey        NVARCHAR(15),
           @n_PackInfoWgt       INT,
           @n_CntPickZone       INT,
           @c_UDF01             NVARCHAR(60),
           @c_ConsigneeFor      NVARCHAR(15),
           @c_Notes             NVARCHAR(80),
           @c_City              NVARCHAR(45),
           @c_GetCol55          NVARCHAR(100),
           @c_Col55             NVARCHAR(80),
           @c_ExecStatements    NVARCHAR(4000),
           @c_ExecArguments     NVARCHAR(4000),
           @c_Picknotes         NVARCHAR(100),
           @c_State             NVARCHAR(45),
           @c_Col35             NVARCHAR(80),
           @c_StorerKey         NVARCHAR(15),
           @c_Door              NVARCHAR(10),
           @c_DeliveryNote      NVARCHAR(10),
           @c_GetShipperKey     NVARCHAR(15),
           @c_GetCodelkup       NVARCHAR(1),
           @c_CNotes            NVARCHAR(200),
           @c_Short             NVARCHAR(25),
           @c_SVAT              NVARCHAR(18),
           @c_Col39             NVARCHAR(80),
           @n_Getcol39          FLOAT,
           @c_GetStorerKey      NVARCHAR(20),
           @c_DocType           NVARCHAR(10),
           @c_OHUdef01          NVARCHAR(20),
           @c_Condition1        NVARCHAR(150),
           @c_Condition2        NVARCHAR(150),
           @n_UnitPrice         INT,
           @c_PickSlipNo        NVARCHAR(10) = '',
           @c_UserDef03         NVARCHAR(80),
           @c_Col37             NVARCHAR(80),
           @c_Col45             NVARCHAR(80),
           @c_Col46             NVARCHAR(80),
           @c_Col47             NVARCHAR(80),
           @c_Col48             NVARCHAR(80),
           @c_Col49             NVARCHAR(80),
           @c_Col50             NVARCHAR(80),
           @c_GetOrderkey       NVARCHAR(10),
           @c_OrderLineNo       NVARCHAR(5),
           @c_GetSKU            NVARCHAR(20),
           @c_AltSku            NVARCHAR(20),
           @c_Color             NVARCHAR(50),    --CS04
           @c_Size              NVARCHAR(50),    --CS04
           @n_Qty               INT,
           @n_ID                INT,
           --CS04 START
          @c_DynamicFlag        NVARCHAR(5),
          @c_DFUdf01            NVARCHAR(60),
          @c_DFUdf02            NVARCHAR(60),
          @c_DFUdf03            NVARCHAR(60),
          @c_skucolumn01        NVARCHAR(50),
          @c_skucolumn02        NVARCHAR(50),
          @c_skucolumn03        NVARCHAR(50),
           --CS04 END
			  --ML01 START
          @c_BAddress2          NVARCHAR(1000),
          @c_BAddress3          NVARCHAR(1000),
          @c_BAddress4          NVARCHAR(1000),
          @c_BPhone1            NVARCHAR(1000),
          @c_BContact1          NVARCHAR(1000),
			 @c_CAddress2          NVARCHAR(1000),
          @c_CAddress3          NVARCHAR(1000),
          @c_CAddress4          NVARCHAR(1000),
          @c_CPhone1            NVARCHAR(1000),
          @c_CContact1          NVARCHAR(1000),
			 @c_mfax1			     NVARCHAR(18)
            --ML01 END

    -- SET RowNo = 0
    SET @c_SQL = ''
    SET @n_SumPickDetQty = 0
    SET @n_SumUnitPrice = 0
    SET @n_UnitPrice = 0

    SET @c_StorerKey = ''
    SET @c_Door = ''
    SET @c_DeliveryNote = ''
    SET @c_GetCodelkup = 'N'
    SET @c_SVAT = ''
    SET @c_condition1 =''
    SET @c_condition2 = ''
    SET @n_id = 1



    CREATE TABLE [#Result] (
      [ID]    [INT] ,--IDENTITY(1, 1) NOT NULL,
      [Col01] [NVARCHAR] (80) NULL,
      [Col02] [NVARCHAR] (80) NULL,
      [Col03] [NVARCHAR] (80) NULL,
      [Col04] [NVARCHAR] (80) NULL,
      [Col05] [NVARCHAR] (80) NULL,
      [Col06] [NVARCHAR] (80) NULL,
      [Col07] [NVARCHAR] (80) NULL,
      [Col08] [NVARCHAR] (80) NULL,
      [Col09] [NVARCHAR] (80) NULL,
      [Col10] [NVARCHAR] (80) NULL,
      [Col11] [NVARCHAR] (80) NULL,
      [Col12] [NVARCHAR] (80) NULL,
      [Col13] [NVARCHAR] (80) NULL,
      [Col14] [NVARCHAR] (80) NULL,
      [Col15] [NVARCHAR] (80) NULL,
      [Col16] [NVARCHAR] (80) NULL,
      [Col17] [NVARCHAR] (80) NULL,
      [Col18] [NVARCHAR] (80) NULL,
      [Col19] [NVARCHAR] (80) NULL,
      [Col20] [NVARCHAR] (80) NULL,
      [Col21] [NVARCHAR] (80) NULL,
      [Col22] [NVARCHAR] (80) NULL,
      [Col23] [NVARCHAR] (80) NULL,
      [Col24] [NVARCHAR] (80) NULL,
      [Col25] [NVARCHAR] (80) NULL,
      [Col26] [NVARCHAR] (80) NULL,
      [Col27] [NVARCHAR] (80) NULL,
      [Col28] [NVARCHAR] (80) NULL,
      [Col29] [NVARCHAR] (80) NULL,
      [Col30] [NVARCHAR] (80) NULL,
      [Col31] [NVARCHAR] (80) NULL,
      [Col32] [NVARCHAR] (80) NULL,
      [Col33] [NVARCHAR] (80) NULL,
      [Col34] [NVARCHAR] (80) NULL,
      [Col35] [NVARCHAR] (80) NULL,
      [Col36] [NVARCHAR] (80) NULL,
      [Col37] [NVARCHAR] (80) NULL,
      [Col38] [NVARCHAR] (80) NULL,
      [Col39] [NVARCHAR] (80) NULL,
      [Col40] [NVARCHAR] (80) NULL,
      [Col41] [NVARCHAR] (80) NULL,
      [Col42] [NVARCHAR] (80) NULL,
      [Col43] [NVARCHAR] (80) NULL,
      [Col44] [NVARCHAR] (80) NULL,
      [Col45] [NVARCHAR] (80) NULL,
      [Col46] [NVARCHAR] (80) NULL,
      [Col47] [NVARCHAR] (80) NULL,
      [Col48] [NVARCHAR] (80) NULL,
      [Col49] [NVARCHAR] (80) NULL,
      [Col50] [NVARCHAR] (80) NULL,
      [Col51] [NVARCHAR] (80) NULL,
      [Col52] [NVARCHAR] (80) NULL,
      [Col53] [NVARCHAR] (80) NULL,
      [Col54] [NVARCHAR] (80) NULL,
      [Col55] [NVARCHAR] (80) NULL,
      [Col56] [NVARCHAR] (80) NULL,
      [Col57] [NVARCHAR] (80) NULL,
      [Col58] [NVARCHAR] (80) NULL,
      [Col59] [NVARCHAR] (80) NULL,
      [Col60] [NVARCHAR] (80) NULL
     )

     CREATE TABLE [#OrdDet] (
      [ID]               [INT] IDENTITY(1,1) NOT NULL,
      [Orderkey]         NVARCHAR(10),
      [OrderLineNo]      NVARCHAR(5),
      [SKU]              NVARCHAR(20),
      [AltSku]           NVARCHAR(20),
      [Color]            NVARCHAR(50),   --CS04
      [Size]             NVARCHAR(50),   --CS04
      [Qty]              INT )

     --CS02 START
     --SELECT TOP 1 @c_StorerKey = ORD.StorerKey
     --FROM ORDERS ORD WITH (NOLOCK)
     --WHERE ORD.loadkey = @c_Sparm1
     SELECT TOP 1 @c_StorerKey = ORD.StorerKey
     FROM loadplandetail (NOLOCK)
     JOIN  ORDERS ORD WITH (NOLOCK) ON ORD.orderkey = loadplandetail.orderkey
     WHERE loadplandetail.loadkey = @c_Sparm1


     --CS02 END

     IF ISNULL(RTRIM(@c_Sparm2),'') <> ''
     BEGIN
        SET @c_condition1 = ' AND ORD.OrderKey =RTRIM(@c_Sparm2)'
     END
     ELSE
     BEGIN
        SET @c_condition1 = ' AND ORD.LoadKey = @c_Sparm1 '

        IF ISNULL(RTRIM(@c_Sparm3),'') <> ''
        BEGIN
           SET @c_condition2 = ' AND ORD.ShipperKey =RTRIM(@c_Sparm3)'
        END
     END

     SET @c_SQLJOIN = +' SELECT DISTINCT @n_id, '
                      + CHAR(13)
                      +' ORD.Loadkey, ORD.Orderkey, ORD.ExternOrderKey, ORD.Type, ORD.BuyerPO, ' --5
                      + CHAR(13)
                      +' ORD.Salesman, ORD.Facility, ISNULL(STO.Secondary,''''),ISNULL(STO.Company,''''), ISNULL(STO.SUSR1,''''), '   --10
                      + CHAR(13)
                      +' ISNULL(STO.SUSR2,''''), ' --11
                      + CHAR(13)
                      +' LEFT(ISNULL(RTRIM(LTRIM(F.Address1)),'''') + ISNULL(RTRIM(LTRIM(F.Address2)),'''') + ISNULL(RTRIM(LTRIM(F.Address3)),''''), 80), ' --12       --(KY01)
                      + CHAR(13)
                      +' ISNULL(ORD.Notes,''''), '''', ORD.Storerkey, ' --15
                      + CHAR(13)
                      +' ISNULL(F.State,''''), ISNULL(F.City,''''), ISNULL(F.Zip,''''), ISNULL(F.Contact1,''''), ISNULL(F.Phone1,''''), '  --20
                      + CHAR(13)
                      + ' ISNULL(F.Phone2,''''), ORD.Consigneekey, ORD.C_Company, ' --23
                      + CHAR(13)
                      --+ ' ISNULL(RTRIM(LTRIM(ORD.C_Address1)),''''), ISNULL(RTRIM(LTRIM(ORD.C_Address2)),''''), '   --25	--ML01
							 + ' ISNULL(RTRIM(LTRIM(ORD.C_Address1)),''''), '''', '   --25	--ML01
                      + CHAR(13)
                      --+ ' ISNULL(RTRIM(LTRIM(ORD.C_Address3)),''''), ISNULL(RTRIM(LTRIM(ORD.C_Address4)),''''), '   --27	--ML01
							 + ' '''', '''', '   --27	--ML01
                      + CHAR(13)
                      + ' ISNULL(RTRIM(LTRIM(ORD.C_State)),''''), ISNULL(RTRIM(LTRIM(ORD.C_City)),''''), ISNULL(RTRIM(LTRIM(ORD.C_Zip)),''''), '   --30
                      + CHAR(13)
                      --+ ' ISNULL(RTRIM(LTRIM(ORD.C_Contact1)),''''), ISNULL(RTRIM(LTRIM(ORD.C_Phone1)),''''), ISNULL(RTRIM(LTRIM(ORD.C_Phone2)),''''), '   --33	--ML01
							 + ' '''', '''', ISNULL(RTRIM(LTRIM(ORD.C_Phone2)),''''), '   --33	--ML01
                      + CHAR(13)
                      + ' ISNULL(RTRIM(LTRIM(ORD.M_Company)),''''), ' --34
                      + CHAR(13)
                      + ' STO.VAT, ISNULL(ORD.UserDefine02,''''), '''', ISNULL(ORD.trackingno,''''), ' --38  --CS03
                      + CHAR(13)
                      + ' ISNULL(ORD.UserDefine05,''''), ISNULL(ORD.PmtTerm,''''), ' --40
                      + CHAR(13)
                      + ' ISNULL(ORD.InvoiceAmount,''''), '''', '''', ORD.Shipperkey, ' --44
                      + CHAR(13)
                      + ' '''', '''', '''', '''', '''', '''', ' --50
                      + CHAR(13)
                      --+ ' '''', ISNULL(RTRIM(LTRIM(ORD.M_Address1)),''''), ISNULL(RTRIM(LTRIM(ORD.M_Address2)),''''), ' --53     --CS01
                      + ' '''', SUBSTRING(CT.Printdata,1,80), SUBSTRING(CT.Printdata,81,80), ' --53            --CS01
                      + CHAR(13)
                     -- + ' ISNULL(RTRIM(LTRIM(ORD.M_City)),''''), '''', ' --55    --CS01
                      + ' SUBSTRING(CT.UDF01,1,80), '''', ' --55      --CS01
                      + CHAR(13)
                      + ' '''', ISNULL(ORD.Priority,''''), ISNULL(ORD.UserDefine10,''''), ISNULL(ORD.DeliveryPlace,''''), ISNULL(ORD.DeliveryNote,'''') ' --60
                      + CHAR(13)
                      + ' FROM ORDERS ORD WITH (NOLOCK) ' + CHAR(13)
                      + ' INNER JOIN STORER STO WITH (NOLOCK) ON STO.StorerKey = ORD.StorerKey '    + CHAR(13)
                      + ' INNER JOIN FACILITY F WITH (NOLOCK) ON F.FACILITY = ORD.FACILITY ' + CHAR(13)
                      + ' LEFT JOIN ORDERINFO ORDIF WITH (NOLOCK) ON ORDIF.orderkey = ORD.Orderkey '  + CHAR(13)
                      + ' LEFT JOIN CARTONTRACK CT WITH (NOLOCK) ON CT.Trackingno = ORD.trackingno ' + CHAR(13)    --CS01 --CS03
                      + ' WHERE ORD.StorerKey = @c_StorerKey '


     IF @b_debug='1'
     BEGIN
        PRINT @c_SQLJOIN
     END

     SET @c_SQL='INSERT INTO #Result (ID, Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +
               +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +
               +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +
               +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +
               +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +
               + ',Col55,Col56,Col57,Col58,Col59,Col60) '

     SET @c_SQL = @c_SQL + @c_SQLJOIN +  CHAR(13) + @c_condition1  + CHAR(13) + @c_condition2


        -- EXEC sp_executesql @c_SQL

     SET @c_ExecArguments = N'   @c_Sparm1           NVARCHAR(80)'
                            + ', @c_Sparm2           NVARCHAR(80)'
                            + ', @c_Sparm3           NVARCHAR(80)'
                            + ', @c_StorerKey        NVARCHAR(80)'
                            + ', @n_ID               NVARCHAR(80)'

     EXEC sp_ExecuteSql @c_SQL
                      , @c_ExecArguments
                      , @c_Sparm1
                      , @c_Sparm2
                      , @c_Sparm3
                      , @c_StorerKey
                      , @n_ID


   IF @b_debug=1
   BEGIN
      PRINT @c_SQL
   END

   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Col02, Col38 from #Result

   OPEN CUR_RowNoLoop

   FETCH NEXT FROM CUR_RowNoLoop INTO @c_OrderKey, @c_Udef04

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_GetStorerKey = ''
      SET @c_DocType  = ''
      SET @c_SVAT = ''
      SET @c_PickSlipNo = ''
      SET @c_OHUdef01 = ''
      SET @c_SVAT = ''

      SELECT @c_GetStorerKey = StorerKey
            ,@c_DocType  = [Type]
            ,@c_OHUdef01 = UserDefine01
      FROM   ORDERS WITH (NOLOCK)
      WHERE  OrderKey = @c_OrderKey

      SELECT @c_SVAT = s.VAT
      FROM STORER AS s WITH (NOLOCK)
      WHERE s.StorerKey = @c_GetStorerKey

      SELECT TOP 1 @c_PickSlipNo = ph.PickSlipNo
      FROM PackHeader AS ph WITH (NOLOCK)
      WHERE ph.OrderKey = @c_OrderKey

      IF @b_debug='1'
      BEGIN
         PRINT @c_OrderKey
      END

      SELECT @n_SumPickDetQty = SUM(QTY),
             @n_SumUnitPrice  = SUM(QTY * ORDDET.Unitprice)
      FROM   PICKDETAIL PD WITH (NOLOCK)
      JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON PD.OrderKey = ORDDET.OrderKey
                                           AND PD.OrderLineNumber = ORDDET.OrderLineNumber
      WHERE  PD.OrderKey = @c_OrderKey

      SELECT @n_PackInfoWgt = SUM(PKI.Weight),
             @c_Col35 = CASE WHEN @c_SVAT = 'ITX'
                           THEN CAST(SUM(CAST(PKI.[Cube] as NUMERIC(6,6))) as NVARCHAR(30))
                           ELSE @c_OHUdef01
                        END
      FROM   PACKINFO PKI WITH (NOLOCK)
      WHERE  PKI.Pickslipno = @c_PickSlipNo

      UPDATE #Result
      SET Col42 = @n_SumPickDetQty,
          Col43 = @n_SumUnitPrice,
          Col56 = @n_PackInfoWgt,
          Col35 = @c_Col35
      WHERE Col02 = @c_OrderKey

      FETCH NEXT FROM CUR_RowNoLoop INTO @c_OrderKey, @c_Udef04
   END

   DECLARE CUR_UpdateRec CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Col02
   FROM #Result

   OPEN CUR_UpdateRec

   FETCH NEXT FROM CUR_UpdateRec INTO @c_OrderKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_ShipperKey = ''
      SET @c_ORDAdd = ''
      SET @c_ConsigneeFor = ''
      SET @c_CLong = ''
      SET @c_notes2 = ''
      SET @c_UDF01 = ''
      SET @c_GetCol55 = ''
      SET @c_Col37 = ''

      SELECT @c_ORDAdd = RTRIM(ORD.C_State) + ' ' + RTRIM(ORD.C_City) + ' ' + RTRIM(ORD.C_Address1)
            ,@c_City   = RTRIM(ORD.C_City)          --(CS20)
            ,@c_State  = RTRIM(ORD.C_State)         --(CS20)
            ,@c_Address1 = RTRIM(ORD.C_Address1)    --(CS20)
            ,@c_StorerKey = ORD.StorerKey
            ,@c_Door      = ORD.Door
            ,@c_DeliveryNote = ORD.DeliveryNote
            ,@c_GetShipperKey = ORD.ShipperKey
            ,@c_ConsigneeKey  = ORD.ConsigneeKey
            ,@c_UserDef03 = ORD.UserDefine03
				--START ML01
				,@c_CAddress2 = RTRIM(ORD.C_Address2)
				,@c_CAddress3 = RTRIM(ORD.C_Address3)
				,@c_CAddress4 = RTRIM(ORD.C_Address4)
				,@c_CPhone1 = RTRIM(ORD.C_Phone1)
				,@c_CContact1 = RTRIM(ORD.C_Contact1)
				--END ML01
      FROM ORDERS ORD WITH (NOLOCK)
      WHERE ORD.Orderkey =   @c_OrderKey

		--START ML01
		SELECT @c_BAddress2 = CONVERT(NVARCHAR,Orders_PI_Encrypted.B_Address2)
            ,@c_BAddress3 = CONVERT(NVARCHAR,Orders_PI_Encrypted.B_Address3)
            ,@c_BAddress4 = CONVERT(NVARCHAR,Orders_PI_Encrypted.B_Address4)
            ,@c_BPhone1 = CONVERT(NVARCHAR,Orders_PI_Encrypted.B_Phone1)
            ,@c_BContact1 = CONVERT(NVARCHAR,Orders_PI_Encrypted.B_Contact1)
      FROM Orders_PI_Encrypted WITH (NOLOCK)
      WHERE Orders_PI_Encrypted.Orderkey =   @c_OrderKey
		--END ML01


      SELECT @c_ConsigneeFor = ISNULL(ConsigneeFor,'')
      FROM  Storer S WITH (NOLOCK)
      WHERE S.StorerKey= @c_GetShipperKey

      IF @b_debug = '1'
      BEGIN
         PRINT ' ORD address combine : ' + @c_ORDAdd + ' with orderkey : ' + @c_OrderKey
      END

      IF @b_debug='1'
      BEGIN
         PRINT ' ConsigneeFor : ' + @c_ConsigneeFor
      END

      IF @c_ConsigneeFor = 'A'
      BEGIN
         SELECT TOP 1 @c_cnotes = c.notes,
                      @c_short = C.short
         FROM Codelkup C WITH (NOLOCK)
         WHERE C.short =  @c_GetShipperKey
         AND C.Listname='COURIERMAP'
         AND C.UDF01='ELABEL'

         SELECT TOP 1
            @c_CLong = C.Long
         FROM Codelkup C WITH (NOLOCK)
         WHERE C.short =  @c_GetShipperKey
         AND C.Listname='COURIERMAP'
         AND C.UDF01='ELABEL'
         AND C.notes LIKE N'%' + @c_City + '%'

         IF @b_debug='1'
         BEGIN
            PRINT ' c_long : ' + @c_CLong
         END

         IF ISNULL(@c_CLong,'') = ''
         BEGIN
             SET @c_CLong = @c_City
         END

         IF @b_debug='1'
         BEGIN
            PRINT ' c_city : ' + @c_City
         END
      END
      ELSE
      BEGIN
         SELECT TOP 1
            @c_CLong = C.Long
         FROM Codelkup C WITH (NOLOCK)
         WHERE C.Short = @c_GetShipperKey
         AND C.Listname='COURIERMAP'
         AND C.UDF01='ELABEL'
         AND c.Notes LIKE N'%'+@c_State+'%' AND c.Notes2 LIKE N'%'+@c_City+'%' AND c.Description LIKE N'%'+@c_Address1+'%'

         IF @b_debug='1'
         BEGIN
            PRINT ' c_long : ' +  @c_CLong
         END
      END

      SELECT @c_SVAT = ISNULL(VAT,'')
      FROM STORER WITH (NOLOCK)
      WHERE StorerKey = @c_StorerKey

      SELECT @c_Col37 = CASE WHEN @c_SVAT = 'ITX' THEN @c_Door ELSE @c_UserDef03 END

      SELECT TOP 1
             @c_UDF01 = C.UDF01
      FROM   Codelkup C WITH (NOLOCK)
      WHERE C.Short = @c_GetShipperKey
      AND C.StorerKey = @c_StorerKey
      AND C.Listname = 'WSCourier'

      SELECT TOP 1 @c_GetCol55 = C.Long
      FROM Codelkup C WITH (NOLOCK)
      WHERE C.listname='ELCOL55'
      AND c.StorerKey = @c_StorerKey             --(CS25)

      IF @b_debug = '1'
      BEGIN
         PRINT ' Get Col55 : ' + @c_GetCol55
      END

      IF ISNULL(@c_GetCol55,'') = ''
      BEGIN
         SET @c_GetCol55 = 'Orders.IncoTerm'
      END

      SET @c_ExecStatements = ''
      SET @c_ExecArguments = ''

      SET @c_ExecStatements = N'SELECT @c_Col55 = ' + @c_GetCol55 + ' FROM ORDERS (NOLOCK) WHERE Orderkey = @c_OrderKey '

      SET @c_ExecArguments = N'@c_GetCol55   NVARCHAR(80) '
                             +',@c_OrderKey  NVARCHAR(30)'
                             +',@c_Col55     NVARCHAR(20) OUTPUT'

      EXEC sp_ExecuteSql @c_ExecStatements
                        , @c_ExecArguments
                        , @c_GetCol55
                        , @c_OrderKey
                        , @c_Col55 OUTPUT

      IF @b_debug = '1'
      BEGIN
	     PRINT ' Col55 : ' + @c_Col55
      END

      IF @b_debug = '1'
      BEGIN
            PRINT ' codelkup long : ' + @c_CLong + 'and notes2 : ' + @c_notes2 +
            ' with orderkey : ' + @c_OrderKey
      END

		--START ML01
		SELECT @c_MFax1 = Orders.M_Fax1
		FROM ORDERS(NOLOCK) 
		WHERE ORDERS.ORDERKEY = @c_OrderKey
		--END ML01

      UPDATE #Result
      SET    Col51     = @c_CLong,
             Col14     = @c_UDF01,
             Col55     = @c_Col55,
             Col37     = @c_Col37,
				 Col25     = CASE WHEN @c_MFax1 = 'PII' THEN @c_BAddress2 ELSE @c_CAddress2 END,	--ML01
				 Col26     = CASE WHEN @c_MFax1 = 'PII' THEN @c_BAddress3 ELSE @c_CAddress3 END,	--ML01
				 Col27     = CASE WHEN @c_MFax1 = 'PII' THEN @c_BAddress4 ELSE @c_CAddress4 END,	--ML01
				 Col32     = CASE WHEN @c_MFax1 = 'PII' THEN @c_BPhone1 ELSE @c_CPhone1 END,	   --ML01
				 Col31     = CASE WHEN @c_MFax1 = 'PII' THEN @c_BContact1 ELSE @c_CContact1 END	--ML01
      WHERE  Col02     = @c_OrderKey
	
       --CS04 START
       SET @c_DynamicFlag = '0'
       SET @c_skucolumn01 = 'SKU.AltSKU'
       SET @c_skucolumn02 = 'SKU.Color'
       SET @c_skucolumn03 = 'SKU.Size'


      SELECT @c_skucolumn01=C.UDF01
            ,@c_skucolumn02=C.UDF02
            ,@c_skucolumn03=C.UDF03
      FROM CODELKUP C (NOLOCK)
      WHERE C.Storerkey = @c_StorerKey
      AND C.LISTNAME  = 'VIPLABEL' AND short='1'
      AND C.Code      = 'Dynamic';


     SET @c_ExecStatements = ''

     SET @c_ExecStatements ='INSERT INTO #OrdDet ([Orderkey], [OrderLineNo], [SKU],
                           [AltSku], [Color], [Size], [Qty] )
	 SELECT DISTINCT TOP 6 ORD.ORDERKEY, ORDET.ORDERLINENUMBER, ORDET.SKU,
                            LTRIM(RTRIM(ISNULL('+@c_skucolumn01+',''''))),
                            LTRIM(RTRIM(ISNULL('+@c_skucolumn02+',''''))),
                            LTRIM(RTRIM(ISNULL('+@c_skucolumn03+',''''))),
                            SUM(PD.Qty)
      FROM ORDERS ORD (NOLOCK)
      JOIN ORDERDETAIL ORDET (NOLOCK) ON ORD.OrderKey = ORDET.OrderKey
      JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = ORD.OrderKey AND PD.OrderLineNumber = ORDET.OrderLineNumber
                                 AND PD.SKU = ORDET.SKU
      JOIN SKU (NOLOCK) ON SKU.SKU = ORDET.SKU AND ORD.StorerKey = SKU.StorerKey
      WHERE   ORD.OrderKey='''+@c_OrderKey+'''
      GROUP BY ORD.ORDERKEY, ORDET.ORDERLINENUMBER , ORDET.SKU,LTRIM(RTRIM(ISNULL('+@c_skucolumn01+',''''))) ,
         LTRIM(RTRIM(ISNULL('+@c_skucolumn02+','''')))  ,LTRIM(RTRIM(ISNULL('+@c_skucolumn03+','''')))
      ORDER BY ORD.ORDERKEY, ORDET.ORDERLINENUMBER'

      EXEC sp_ExecuteSQL @c_ExecStatements

      IF @b_debug = '1'
      BEGIN
	     PRINT @c_ExecStatements
	  END
      --SELECT DISTINCT TOP 6 ORD.ORDERKEY, ORDET.ORDERLINENUMBER, ORDET.SKU,
      --                      LTRIM(RTRIM(ISNULL(SKU.ALTSKU,''))),
      --                      LTRIM(RTRIM(ISNULL(SKU.Color,''))),
      --                      LTRIM(RTRIM(ISNULL(SKU.Size,''))),
      --                      SUM(PD.Qty)
      --FROM ORDERS ORD (NOLOCK)
      --JOIN ORDERDETAIL ORDET (NOLOCK) ON ORD.OrderKey = ORDET.OrderKey
      --JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = ORD.OrderKey AND PD.OrderLineNumber = ORDET.OrderLineNumber
      --                           AND PD.SKU = ORDET.SKU
      --JOIN SKU (NOLOCK) ON SKU.SKU = ORDET.SKU AND ORD.StorerKey = SKU.StorerKey
      --WHERE ORD.OrderKey = @c_OrderKey
      --GROUP BY ORD.ORDERKEY, ORDET.ORDERLINENUMBER , ORDET.SKU,LTRIM(RTRIM(ISNULL(SKU.ALTSKU,''))) ,
      --         LTRIM(RTRIM(ISNULL(SKU.Color,'')))  ,LTRIM(RTRIM(ISNULL(SKU.Size,'')))
      --ORDER BY ORD.ORDERKEY, ORDET.ORDERLINENUMBER


 --CS04 END
      SET @c_Col45 = ''
      SET @c_Col46 = ''
      SET @c_Col47 = ''
      SET @c_Col48 = ''
      SET @c_Col49 = ''
      SET @c_Col50 = ''


      DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT [ID], [Orderkey], [OrderLineNo], [SKU],
                      [AltSku], [Color], [Size], [Qty]
      FROM #OrdDet
      WHERE [Orderkey] = @c_OrderKey
      ORDER BY ID

      OPEN CUR_RESULT

      FETCH NEXT FROM CUR_RESULT INTO @n_ID, @c_GetOrderkey, @c_OrderLineNo, @c_GetSKU, @c_AltSku
                                    , @c_Color, @c_Size, @n_Qty
      WHILE @@FETCH_STATUS <>-1
      BEGIN
         IF @n_ID = 1
         BEGIN
            SET @c_Col45 = @c_AltSku + '*' + @c_Color + '*' + @c_Size + '*' + CAST(@n_Qty AS NVARCHAR(10))
         END
         ELSE IF @n_ID = 2
         BEGIN
            SET @c_Col46 = @c_AltSku + '*' + @c_Color + '*' + @c_Size + '*' + CAST(@n_Qty AS NVARCHAR(10))
         END
         ELSE IF @n_ID = 3
         BEGIN
            SET @c_Col47 = @c_AltSku + '*' + @c_Color + '*' + @c_Size + '*' + CAST(@n_Qty AS NVARCHAR(10))
         END
         ELSE IF @n_ID = 4
         BEGIN
            SET @c_Col48 = @c_AltSku + '*' + @c_Color + '*' + @c_Size + '*' + CAST(@n_Qty AS NVARCHAR(10))
         END
         ELSE IF @n_ID = 5
         BEGIN
            SET @c_Col49 = @c_AltSku + '*' + @c_Color + '*' + @c_Size + '*' + CAST(@n_Qty AS NVARCHAR(10))
         END
         ELSE IF @n_ID = 6
         BEGIN
            SET @c_Col50 = @c_AltSku + '*' + @c_Color + '*' + @c_Size + '*' + CAST(@n_Qty AS NVARCHAR(10))
         END

         FETCH NEXT FROM CUR_RESULT INTO @n_ID, @c_GetOrderkey, @c_OrderLineNo, @c_GetSKU, @c_AltSku
                                       , @c_Color, @c_Size, @n_Qty
      END

      CLOSE CUR_RESULT
      DEALLOCATE CUR_RESULT

      UPDATE #Result
      SET Col45 = @c_Col45,
          Col46 = @c_Col46,
          Col47 = @c_Col47,
          Col48 = @c_Col48,
          Col49 = @c_Col49,
          Col50 = @c_Col50
      WHERE Col02 = @c_OrderKey

      FETCH NEXT FROM CUR_UpdateRec INTO @c_OrderKey

   END -- While
   CLOSE CUR_UpdateRec
   DEALLOCATE CUR_UpdateRec

   SELECT * FROM #Result WITH (NOLOCK)

   EXIT_SP:

END -- procedure


GO
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
/* 2019-08-07 1.0  WLCHOOI    Created (WMS-10174)                             */
/* 2021-04-02 1.1  CSCHONG    WMS-16024 PB-Standardize TrackingNo (CS01)      */
/* 2022-09-21 1.2  MINGLE     WMS-20833 change storerkey to consigneekey(ML01)*/
/******************************************************************************/

CREATE PROC [dbo].[isp_BT_Bartender_Shipper_Label_14]
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
           @c_Color             NVARCHAR(10),
           @c_Size              NVARCHAR(10),
           @n_Qty               INT,
           @n_ID                INT,
           @c_ExternOrderkey    NVARCHAR(50),
           @c_DropID            NVARCHAR(50)

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
      [ID]    [INT] IDENTITY(1, 1) NOT NULL,
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

     IF ISNULL(RTRIM(@c_Sparm1),'') <> ''
     BEGIN
        SET @c_condition1 = ' AND PID.DropID = RTRIM(@c_Sparm1)'
        SELECT TOP 1 @c_StorerKey = PID.StorerKey
        FROM PICKDETAIL PID WITH (NOLOCK)
        WHERE PID.DropID = @c_Sparm1
     END

     IF ISNULL(RTRIM(@c_Sparm2),'') <> ''
     BEGIN
        SET @c_condition2 = ' AND ORD.ExternOrderkey = RTRIM(@c_Sparm2)'
        SELECT TOP 1 @c_StorerKey = ORD.StorerKey
        FROM ORDERS ORD WITH (NOLOCK)
        WHERE ORD.ExternOrderKey = @c_Sparm2
     END

     SET @c_SQLJOIN = +' SELECT DISTINCT '
                      + CHAR(13)
                      +' ORD.Loadkey, ORD.Orderkey, ORD.ExternOrderKey, ORD.Type, ORD.Storerkey, ' --5
                      + CHAR(13)
                      +' ISNULL(RTRIM(LTRIM(ORD.C_Contact1)),''''), ISNULL(RTRIM(LTRIM(ORD.C_Phone1)),''''), ISNULL(ORD.trackingno,''''), ' --8  --CS01
                      + CHAR(13)
                      +' ISNULL(RTRIM(LTRIM(STO.Address1)),'''') + ISNULL(RTRIM(LTRIM(STO.Address2)),'''') + ISNULL(RTRIM(LTRIM(STO.Address3)),''''), '   --9
                      + CHAR(13)
                      +' ISNULL(ORD.DeliveryPlace,''''), '   --10
                      + CHAR(13)
                      +' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' --20
                      + CHAR(13)
                      +' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' --30
                      + CHAR(13)
                      +' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' --40
                      + CHAR(13)
                      +' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' --50
                      + CHAR(13)
                      +' '''', '''', '''', '''', '''', '''', '''', PID.DropID, ORD.ExternOrderkey, ''CN'' ' --60
                      + CHAR(13)
                      + ' FROM ORDERS ORD WITH (NOLOCK) '      + CHAR(13)
                      --+ ' INNER JOIN STORER STO WITH (NOLOCK) ON STO.StorerKey = ORD.StorerKey '    + CHAR(13)
							 + ' INNER JOIN STORER STO WITH (NOLOCK) ON STO.StorerKey = ORD.Consigneekey ' + CHAR(13)	--ML01
                      + ' INNER JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = ORD.Orderkey '    + CHAR(13)
                      + ' INNER JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno ' + CHAR(13)
                      + ' INNER JOIN PICKDETAIL PID WITH (NOLOCK) ON PID.Orderkey = ORD.Orderkey  ' + CHAR(13)
                      + ' WHERE ORD.StorerKey = @c_StorerKey '-- + CHAR(13)
                   --   + ' AND ORD.ExternOrderkey = @c_Sparm2 ' + CHAR(13)
                   --   + ' AND PID.DropID = @c_Sparm1 '         + CHAR(13)


     IF @b_debug='1'
     BEGIN
        PRINT @c_SQLJOIN
     END

     SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +
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

     EXEC sp_ExecuteSql @c_SQL
                      , @c_ExecArguments
                      , @c_Sparm1
                      , @c_Sparm2
                      , @c_Sparm3
                      , @c_StorerKey

   IF @b_debug=1
   BEGIN
      PRINT @c_SQL
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
            ,@c_City   = RTRIM(ORD.C_City)
            ,@c_State  = RTRIM(ORD.C_State)
            ,@c_Address1 = RTRIM(ORD.C_Address1)
            ,@c_StorerKey = ORD.StorerKey
            ,@c_Door      = ORD.Door
            ,@c_DeliveryNote = ORD.DeliveryNote
            ,@c_GetShipperKey = ORD.ShipperKey
            ,@c_ConsigneeKey  = ORD.ConsigneeKey
            ,@c_UserDef03 = ORD.UserDefine03
      FROM ORDERS ORD WITH (NOLOCK)
      WHERE ORD.Orderkey =   @c_OrderKey

      SELECT @c_ConsigneeFor = ISNULL(ConsigneeFor,'')
      FROM  Storer S WITH (NOLOCK)
      WHERE S.StorerKey= @c_GetShipperKey

      IF @b_debug = '1'
      BEGIN
         PRINT ' ORD address combine : ' + @c_ORDAdd + ' with orderkey : ' + @c_OrderKey
      END

      IF @b_debug='1'
      BEGIN
         Print ' ConsigneeFor : ' + @c_ConsigneeFor
      END

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
      AND C.notes like N'%' + @c_City + '%'

      IF @b_debug='1'
      BEGIN
         Print ' c_long : ' + @c_CLong
      END

      IF ISNULL(@c_CLong,'') = ''
      BEGIN
          SET @c_CLong = @c_City
      END

      IF @b_debug='1'
      BEGIN
         Print ' c_city : ' + @c_City
      END

      SELECT @n_Qty = SUM(PD.Qty)
      FROM ORDERS ORD WITH (NOLOCK)
      INNER JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = ORD.Orderkey
      INNER JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
      WHERE PH.OrderKey = @c_OrderKey

      UPDATE #Result
      SET    Col50     = @c_CLong
            ,Col11     = @n_Qty
      WHERE  Col02     = @c_OrderKey

      FETCH NEXT FROM CUR_UpdateRec INTO @c_OrderKey

   END -- While
   CLOSE CUR_UpdateRec
   DEALLOCATE CUR_UpdateRec

   SELECT * FROM #Result WITH (NOLOCK)

   EXIT_SP:

END -- procedure


GO
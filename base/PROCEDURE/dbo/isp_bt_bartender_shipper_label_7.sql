SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Copyright: IDS                                                             */  
/* Creation Date : 22-JUN-2018                                                */  
/* Purpose: BarTender Filter by ShipperKey.Duplicate from                     */  
/*            isp_BT_Bartender_Shipper_Label_1 cater for diffrence field      */  
/*            WMS-5363 CN Pandora New B2B Courier Label                       */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date         Rev  Author     Purposes                                      */  
/* 14-Sep-2018  1.0  CSCHONG    WMS-5363-add new field (CS01)                 */  
/* 29-Jan-2019  1.1  AikLiang   INC0566427 - Removed OrderDetail JOIN to fix  */  
/*                              incorrect Qty issue (AL01)                    */  
/* 2021-04-02   1.2 CSCHONG     WMS-16024 PB-Standardize TrackingNo (CS02)    */  
/* 2022-05-19   1.3 MINGLE      WMS-19675 Add filter for 'SF2' (ML01)         */  
/******************************************************************************/  
  
CREATE PROC [dbo].[isp_BT_Bartender_Shipper_Label_7]  
(  @c_Sparm1            NVARCHAR(250),  
   @c_Sparm2            NVARCHAR(250),  
   @c_Sparm3            NVARCHAR(250),  
   @c_Sparm4            NVARCHAR(250)='',  
   @c_Sparm5            NVARCHAR(250)='',  
   @c_Sparm6            NVARCHAR(250)='',  
   @c_Sparm7            NVARCHAR(250)='',  
   @c_Sparm8            NVARCHAR(250)='',  
   @c_Sparm9            NVARCHAR(250)='',  
   @c_Sparm10           NVARCHAR(250)='',  
   @b_debug             INT = 0  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
      @c_OrderKey        NVARCHAR(10),  
      @c_ExternOrderKey  NVARCHAR(50),  
      @c_Deliverydate    DATETIME,  
      @c_ConsigneeKey    NVARCHAR(15),  
      @c_Company         NVARCHAR(45),  
      @C_Address1        NVARCHAR(45),  
      @C_Address2        NVARCHAR(45),  
      @C_Address3        NVARCHAR(45),  
      @C_Address4        NVARCHAR(45),  
      @C_BuyerPO         NVARCHAR(20),  
      @C_notes2          NVARCHAR(4000),  
      @c_OrderLineNo     NVARCHAR(5),  
      @c_SKU             NVARCHAR(20),  
      @n_Qty             INT,  
      @c_PackKey         NVARCHAR(10),  
      @c_UOM             NVARCHAR(10),  
      @C_PHeaderKey      NVARCHAR(18),  
      @C_SODestination   NVARCHAR(30)  
  
  DECLARE @n_RowNo             INT,  
          @n_SumPickDETQTY     INT,  
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
          @c_consigneeFor      NVARCHAR(15),  
          @c_notes             NVARCHAR(80),  
          @c_City              NVARCHAR(45),  
          @c_GetCol55          NVARCHAR(100),  
          @c_Col55             NVARCHAR(80),  
          @c_ExecStatements    NVARCHAR(4000),  
          @c_ExecArguments     NVARCHAR(4000),  
          @c_picknotes         NVARCHAR(100),  
          @c_State             NVARCHAR(45),  
          @c_col35             NVARCHAR(80),  
          @c_storerkey         NVARCHAR(15),  
          @c_Door              NVARCHAR(10),  
          @c_deliveryNote      NVARCHAR(10),  
          @c_GetShipperKey     NVARCHAR(15),  
          @c_GetCodelkup       NVARCHAR(1),  
          @c_cNotes            NVARCHAR(200),  
          @c_short             NVARCHAR(25),  
          @c_SVAT              NVARCHAR(18),  
          @c_col39             NVARCHAR(80),  
          @n_getcol39          INT,  
          @c_getstorerkey      NVARCHAR(20),  
          @c_doctype           NVARCHAR(10),  
          @c_OHUdef01          NVARCHAR(20),  
          @c_condition         NVARCHAR(150),  
          @c_cartonNo          NVARCHAR(5),  
          @c_GetCol53          NVARCHAR(100),  
          @c_Col53             NVARCHAR(80),  
          @c_Col56             NVARCHAR(80),  
    @c_Code              NVARCHAR(10)  
  
  DECLARE @d_Trace_StartTime   DATETIME,  
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),  
           @d_Trace_Step1      DATETIME,  
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),  
           @n_startCtn         INT,  
           @n_EndCtn           INT  
  
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
  
    -- SET RowNo = 0  
    SET @c_SQL = ''  
    SET @n_SumPickDETQTY = 0  
    SET @n_SumUnitPrice = 0  
  
    SET @c_storerkey = ''  
    SET @c_Door = ''  
    SET @c_deliveryNote = ''  
    SET @c_GetCodelkup = 'N'  
    SET @c_SVAT = ''  
    SET @n_startCtn =   0  
    SET @n_EndCtn    = 0  
  
    CREATE TABLE [#Result]  
    (  
     [ID]        [INT] IDENTITY(1, 1) NOT NULL,  
     [Col01]     [NVARCHAR] (80) NULL,  
     [Col02]     [NVARCHAR] (80) NULL,  
     [Col03]     [NVARCHAR] (80) NULL,  
     [Col04]     [NVARCHAR] (80) NULL,  
     [Col05]     [NVARCHAR] (80) NULL,  
     [Col06]     [NVARCHAR] (80) NULL,  
     [Col07]     [NVARCHAR] (80) NULL,  
     [Col08]     [NVARCHAR] (80) NULL,  
     [Col09]     [NVARCHAR] (80) NULL,  
     [Col10]     [NVARCHAR] (80) NULL,  
     [Col11]     [NVARCHAR] (80) NULL,  
     [Col12]     [NVARCHAR] (80) NULL,  
     [Col13]     [NVARCHAR] (80) NULL,  
     [Col14]     [NVARCHAR] (80) NULL,  
     [Col15]     [NVARCHAR] (80) NULL,  
     [Col16]     [NVARCHAR] (80) NULL,  
     [Col17]     [NVARCHAR] (80) NULL,  
     [Col18]     [NVARCHAR] (80) NULL,  
     [Col19]     [NVARCHAR] (80) NULL,  
     [Col20]     [NVARCHAR] (80) NULL,  
     [Col21]     [NVARCHAR] (80) NULL,  
     [Col22]     [NVARCHAR] (80) NULL,  
     [Col23]     [NVARCHAR] (80) NULL,  
     [Col24]     [NVARCHAR] (80) NULL,  
     [Col25]     [NVARCHAR] (80) NULL,  
     [Col26]     [NVARCHAR] (80) NULL,  
     [Col27]     [NVARCHAR] (80) NULL,  
     [Col28]     [NVARCHAR] (80) NULL,  
     [Col29]     [NVARCHAR] (80) NULL,  
     [Col30]     [NVARCHAR] (80) NULL,  
     [Col31]     [NVARCHAR] (80) NULL,  
     [Col32]     [NVARCHAR] (80) NULL,  
     [Col33]     [NVARCHAR] (80) NULL,  
     [Col34]     [NVARCHAR] (80) NULL,  
     [Col35]     [NVARCHAR] (80) NULL,  
     [Col36]     [NVARCHAR] (80) NULL,  
     [Col37]     [NVARCHAR] (80) NULL,  
     [Col38]     [NVARCHAR] (80) NULL,  
     [Col39]     [NVARCHAR] (80) NULL,  
     [Col40]     [NVARCHAR] (80) NULL,  
     [Col41]     [NVARCHAR] (80) NULL,  
     [Col42]     [NVARCHAR] (80) NULL,  
     [Col43]     [NVARCHAR] (80) NULL,  
     [Col44]     [NVARCHAR] (80) NULL,  
     [Col45]     [NVARCHAR] (80) NULL,  
     [Col46]     [NVARCHAR] (80) NULL,  
     [Col47]     [NVARCHAR] (80) NULL,  
     [Col48]     [NVARCHAR] (80) NULL,  
     [Col49]     [NVARCHAR] (80) NULL,  
     [Col50]     [NVARCHAR] (80) NULL,  
     [Col51]     [NVARCHAR] (80) NULL,  
     [Col52]     [NVARCHAR] (80) NULL,  
     [Col53]     [NVARCHAR] (80) NULL,  
     [Col54]     [NVARCHAR] (80) NULL,  
     [Col55]     [NVARCHAR] (80) NULL,  
     [Col56]     [NVARCHAR] (80) NULL,  
     [Col57]     [NVARCHAR] (80) NULL,  
     [Col58]     [NVARCHAR] (80) NULL,  
     [Col59]     [NVARCHAR] (80) NULL,  
     [Col60]     [NVARCHAR] (80) NULL  
    )  
  
    CREATE TABLE [#PICK]  
    (  
     [ID]             [INT] IDENTITY(1, 1) NOT NULL,  
     [OrderKey]       [NVARCHAR] (80) NULL,  
     [TTLPICKQTY]     [INT] NULL,  
     [PickZone]       [INT] NULL,  
     [picknotes]      [nvarchar] (100) NULL  
    )  
  
 --SELECT DISTINCT @c_Code = C.code  
 --   FROM Codelkup C WITH (NOLOCK)  
 --   WHERE C.Listname='PDACOURIER'  
 --AND C.Code = @c_GetShipperKey  
  
   IF @b_debug = 1  
   BEGIN  
       PRINT 'start ' +   @c_Sparm4  
   END  
  
  
     SET @c_SQLJOIN = +' SELECT DISTINCT ORD.loadkey,ORD.orderkey,ORD.externorderkey,ORD.type,ORD.Storerkey,'  
              + ' ORD.C_Contact1,ORD.C_Phone1,ORD.trackingno,substring((STO.Address1+STO.Address2+STO.Address3),1,80),'    --9  --CS02  
                + CHAR(13) +  
                +'ORD.DeliveryPlace,SUM(PD.QTY),'''','''','''','''','''','  --16  
                + CHAR(13) +  
                +''''','''','''','''','''','''','''','''','+ CHAR(13) +  
                +''''','''','''','''','''','''','''','''','  
                +''''','''','''','  
                +''''','''',' --ORD.PmtTerm,'  
                + CHAR(13) +  
                +' '''','  
                +''''','''','''','  
                +''''','''','''','''','''','''','''', '''','''' ,'  --50  
                +' '''','''','''','''','  
                + ' '''','''','''','''','''','''' '  
                + CHAR(13) +  
                + ' FROM ORDERS ORD WITH (NOLOCK) ' --JOIN ORDERDETAIL ORDDET WITH (NOLOCK)  ON ORD.ORDERKEY = ORDDET.ORDERKEY   '  -- AL01  
                + ' JOIN STORER STO WITH (NOLOCK) ON STO.STORERKEY = ORD.Consigneekey '  
                + ' JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = ORD.OrderKey'  
                + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno '--AND PD.sku = ORDDET.sku'   -- AL01  
    + ' LEFT OUTER JOIN CODELKUP C(NOLOCK) ON ( C.LISTNAME = ''PDACOURIER'')  '  
      --          + ' LEFT OUTER JOIN PACKINFO (NOLOCK) ON ( PD.PickSlipNo = PACKINFO.PickSlipNo '  
      --+'        AND PD.CartonNo = PACKINFO.CartonNo )     '  
                + ' WHERE ORD.LoadKey = @c_Sparm1 '  
                + ' AND ORD.OrderKey =  @c_Sparm2 '  
      + ' AND ORD.Doctype=''N'' AND ORD.Shipperkey = C.CODE ' --ML01  
               -- + ' AND ORD.ShipperKey = CASE WHEN ISNULL(RTRIM(@c_Sparm3),'''') <> '''' THEN @c_Sparm3 ELSE ORD.ShipperKey END'  
             --   + ' AND PD.QTY = ''1'' '  
       + ' GROUP BY ORD.loadkey,ORD.orderkey,ORD.externorderkey,ORD.type,ORD.Storerkey,'  
     + ' ORD.C_Contact1,ORD.C_Phone1,ORD.trackingno,substring((STO.Address1+STO.Address2+STO.Address3),1,80),ORD.DeliveryPlace'  --CS02  
  
  
      IF @b_debug = 1  
      BEGIN  
        PRINT @c_condition  
          PRINT @c_SQLJOIN  
      END  
  
  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +  
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +  
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +  
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +  
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +  
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '  
  
   SET @c_SQL = @c_SQL + @c_SQLJOIN  
  
     SET @c_ExecArguments = N' @c_Sparm1           NVARCHAR(80)'  
                          + ', @c_Sparm2           NVARCHAR(80) '  
                          + ', @c_Sparm3           NVARCHAR(80)'  
  
  
   EXEC sp_ExecuteSql     @c_SQL  
                        , @c_ExecArguments  
                        , @c_Sparm1  
                        , @c_Sparm2  
                        , @c_Sparm3  
  
  
  --EXEC sp_executesql @c_SQL  
  
   IF @b_debug = 1  
   BEGIN  
       PRINT @c_SQL  
   END  
  
   IF @b_debug = 1  
   BEGIN  
       SELECT *  
       FROM   #Result(NOLOCK)  
   END  
  
 DECLARE CUR_UpdateRec CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Col02  
   FROM #Result  
  
   OPEN CUR_UpdateRec  
  
   FETCH NEXT FROM CUR_UpdateRec INTO @c_OrderKey  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      --SET @c_ShipperKey = ''  
      --SET @c_ORDAdd = ''  
  
      SELECT @c_City          = RTRIM(C_City)  
            ,@c_GetShipperKey = ShipperKey  
      FROM ORDERS WITH (NOLOCK)  
      WHERE Orderkey =   @c_OrderKey  
  
      SET @c_CLong = ''  
  
         SELECT TOP 1  
            @c_CLong = C.Long  
         FROM Codelkup C WITH (NOLOCK)  
         WHERE C.short =  @c_GetShipperKey  
         AND C.Listname='COURIERMAP'  
         AND C.UDF01='ELABEL'  
         AND c.notes LIKE N'%' + @c_City + '%'  
  
   --SET @c_Code = ''  
  
   --      SELECT TOP 1  
   --         @c_Code = C.Code  
   --      FROM Codelkup C WITH (NOLOCK)  
   --      WHERE C.Code =  @c_GetShipperKey  
   --      AND C.Listname='DPACOURIER'  
  
  
      UPDATE #Result  
      SET    Col50     = @c_CLong  
      WHERE  Col02     = @c_OrderKey  
  
      FETCH NEXT FROM CUR_UpdateRec INTO @c_OrderKey  
  
   END -- While  
   CLOSE CUR_UpdateRec  
   DEALLOCATE CUR_UpdateRec  
  
  
    SELECT *  
    FROM   #Result WITH (NOLOCK)  
    ORDER BY Col02  
  
  
EXIT_SP:  
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
  
   EXEC isp_InsertTraceInfo  
      @c_TraceCode = 'BARTENDER',  
      @c_TraceName = 'isp_BT_Bartender_Shipper_Label_7',  
      @c_starttime = @d_Trace_StartTime,  
      @c_endtime = @d_Trace_EndTime,  
      @c_step1 = @c_UserName,  
      @c_step2 = '',  
      @c_step3 = '',  
      @c_step4 = '',  
      @c_step5 = '',  
      @c_col1 = @c_Sparm1,  
      @c_col2 = @c_Sparm2,  
      @c_col3 = @c_Sparm3,  
      @c_col4 = @c_Sparm4,  
      @c_col5 = @c_Sparm5,  
      @b_Success = 1,  
      @n_Err = 0,  
      @c_ErrMsg = ''  
  
END -- procedure  

GO
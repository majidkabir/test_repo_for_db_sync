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
/* Date        Rev  Author     Purposes                                       */
/* 2022-MAR-10 1.0  CSCHONG    Devops Scripts Combine AND Created (WMS-19112) */
/******************************************************************************/

CREATE PROC [dbo].[isp_BT_Bartender_KR_Shipper_Label_UA]
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

   DECLARE
      @c_OrderKey        NVARCHAR(10),
      @c_ExternOrderKey  NVARCHAR(10),
      @c_Deliverydate    DATETIME,
      @c_labelno         NVARCHAR(20),
      @c_cntNo           NVARCHAR(5),
      @c_ORDUDef10       NVARCHAR(20),
      @c_ORDUDef03       NVARCHAR(20),
      @c_ItemClass       NVARCHAR(10),
      @c_SKUGRP          NVARCHAR(10),
      @c_Style           NVARCHAR(20),
      @n_intFlag         INT,
      @n_CntRec          INT,
      @n_cntsku          INT,
      @c_Lott01          NVARCHAR(18),
      @c_Lott03          NVARCHAR(18),
      @c_Lott06          NVARCHAR(30),
      @c_Lott07          NVARCHAR(30),
      @c_Lott08          NVARCHAR(30),
      @c_ODSKU           NVARCHAR(20),
      @c_SALTSKU         NVARCHAR(20),
      @C_SDESCR          NVARCHAR(60),
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
      @C_SODestination   NVARCHAR(30),
      @n_RowNo           INT,
      @n_SumPickDETQTY   INT,
      @n_SumUnitPrice    INT,
      @c_SQL             NVARCHAR(4000),
      @c_SQLSORT         NVARCHAR(4000),
      @c_SQLJOIN         NVARCHAR(4000),
      @c_Udef04          NVARCHAR(80),
      @n_TTLPickQTY      INT,
      @c_ShipperKey      NVARCHAR(15),
      @n_CntLot03        INT,
      @c_RefNo2          NVARCHAR(30),
      @c_CntRefNo2       INT,
      @n_CntLabel        INT,
      @c_PStatus         NVARCHAR(1),
      @c_GetCol32        NVARCHAR(80) ,
	   @c_GetCol45        NVARCHAR(80),  
	   @c_getlabelno      NVARCHAR(50),  
	   @c_CCode           NVARCHAR(20),  
	   @c_CCode1          NVARCHAR(20),  
	   @c_CCode2          NVARCHAR(20),  
	   @c_CCode3          NVARCHAR(20),  
	   @c_CCode4          NVARCHAR(20),  
	   @c_CCode5          NVARCHAR(20),  
	   @c_CCode6          NVARCHAR(20),  
	   @c_Col46           NVARCHAR(80),  
	   @c_dropid          NVARCHAR(80),
      @c_storerkey       NVARCHAR(20)      

  DECLARE @d_Trace_StartTime   DATETIME,
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20),
           @d_Trace_Step1      DATETIME,
           @c_Trace_Step1      NVARCHAR(20),
           @c_UserName         NVARCHAR(20),
           @c_ExecStatements   NVARCHAR(4000),  
           @c_ExecArguments    NVARCHAR(4000)   

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''

    -- SET RowNo = 0
    SET @c_SQL = ''
    SET @n_SumPickDETQTY = 0
    SET @n_SumUnitPrice = 0
    SET @c_RefNo2 = ''
    SET @n_CntLabel = 0
    SET @c_PStatus = ''
    SET @c_CCode1 = 'X'
	 SET @c_CCode2 ='X'
	 SET @c_CCode3 = 'X'
	 SET @c_CCode4 = 'X'
	 SET @c_CCode5 = 'X'
	 SET @c_CCode6 = 'X'


    CREATE TABLE [#Result] (
      [ID]    [INT] IDENTITY(1,1) NOT NULL,
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


     CREATE TABLE [#CartonContent] (
      [ID]          [INT] IDENTITY(1,1) NOT NULL,
      [DUdef10]     [NVARCHAR] (20) NULL,
      [DUdef03]     [NVARCHAR] (20) NULL,
      [itemclass]   [NVARCHAR] (10) NULL,
      [skugroup]    [NVARCHAR] (10) NULL,
      [style]       [NVARCHAR] (20) NULL,
      [TTLPICKQTY]  [INT] NULL)

    CREATE TABLE [#COO] (
      [ID]          [INT] IDENTITY(1,1) NOT NULL,
      [Lottable03]  [NVARCHAR] (80) NULL)

	CREATE TABLE [#SKUNotes] (
      [ID]          [INT] IDENTITY(1,1) NOT NULL,
      [Labelno]     [NVARCHAR] (20) NULL,
	  [CCode]       [NVARCHAR] (20) NULL
	  )




  SET @c_SQLJOIN = +'SELECT DISTINCT F.DESCR,F.Address1,F.Address2,F.Address3,F.Address4,'
                   +' F.City,F.State,F.zip,F.Country,S.company,'
                   +' MB.externmbolkey,MB.carrierkey,MB.mbolkey,ORD.consigneekey,ORD.c_company,'
                   +' ORD.c_address1,ORD.c_address2,ORD.c_address3,ORD.c_address4,ORD.c_city,'
                   +' ORD.c_state,ORD.c_zip,ORD.c_country,ORD.c_ISOCntryCode,ORD.Type,'
                   +' ORD.externorderkey,ORD.externpokey,ORD.buyerpo,ORD.Orderkey,PIF.CartonType,'
                   +' PD.CartonNo,'''',PD.Labelno,'''','''', '
                   +' '''','''','''',ORD.Shipperkey,ORD.Userdefine02,'     --40          
                   +' '''','''',PD.DropID,ORD.loadkey,'''','''','''','''','''','''', '  --50   
                   +' '''','''','''','''','''','''','''','''','''',ORD.storerkey '   --60
                   +' FROM ORDERS ORD WITH (NOLOCK) '
                   +' JOIN FACILITY F WITH (NOLOCK) ON F.facility = ORD.Facility'
                   +' LEFT JOIN MBOL MB WITH (NOLOCK) ON MB.Mbolkey = ORD.Mbolkey'
                   +' JOIN STORER S WITH (NOLOCK) ON S.storerkey = ORD.Storerkey'
                   +' JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = ORD.OrderKey'
                   +' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno '
                   +' LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.Pickslipno = PD.Pickslipno '
                   +' AND PIF.CartonNo = PD.CartonNo '
                   + ' WHERE PD.Pickslipno =  @c_Sparm1'                                           
                   + ' AND PD.Cartonno >= CONVERT(INT,  @c_Sparm2)'                                
                   + ' AND PD.Cartonno <= CONVERT(INT,  @c_Sparm3)'                                
   IF @b_debug=1
   BEGIN
      PRINT @c_SQLJOIN
   END

  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '

   SET @c_SQL = @c_SQL + @c_SQLJOIN

    --CS04 start
   SET @c_ExecArguments = N'   @c_Sparm1           NVARCHAR(80)'
                          + ', @c_Sparm2           NVARCHAR(80) '
                          + ', @c_Sparm3           NVARCHAR(80)'


   EXEC sp_ExecuteSql     @c_SQL
                        , @c_ExecArguments
                        , @c_Sparm1
                        , @c_Sparm2
                        , @c_Sparm3


   IF @b_debug=1
   BEGIN
      PRINT @c_SQL
   END
   IF @b_debug=1
   BEGIN
      SELECT * FROM #Result (nolock)
   END


   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

   SELECT DISTINCT col29,col31,Col33,col43,col60          
   FROM #Result

   OPEN CUR_RowNoLoop

   FETCH NEXT FROM CUR_RowNoLoop INTO @c_orderkey,@c_CntNo,@c_labelno ,@c_dropid,@c_storerkey      

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @b_debug='1'
      BEGIN
         PRINT @c_labelno
      END

	   SELECT @n_CntLabel = Count(distinct cartonno)
             ,@c_PStatus = P.Status
       FROM PACKHEADER P WITH (NOLOCK)
       JOIN PACKDETAIL PD WITH (NOLOCK) ON P.Pickslipno=PD.Pickslipno
       WHERE PD.Pickslipno = @c_Sparm1
       GROUP BY P.Status


	  INSERT INTO #SKUNotes (Labelno,CCode)
	  SELECT pdet.labelno,c.code
	  FROM   PACKHEADER PH (NOLOCK)
	  JOIN PACKDETAIL PDET (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno
	  JOIN SKU S WITH (NOLOCK) ON S.storerkey = PDET.storerkey and S.SKU = PDET.SKU
	  JOIN codelkup C WITH (NOLOCK) ON C.listname='UABATLABEL' and c.short = s.notes1
										  AND c.storerkey = PH.storerkey
	  where PDET.cartonno=convert(INT,@c_Cntno)
	  and PDET.labelno=@c_labelno
     AND PDET.storerkey = @c_storerkey
	  order by c.code

	  SET @c_GetCol45 = ''
	  SET @c_Col46 = '0'


	  SELECT @c_Col46 = CASE WHEN PD.pickmethod='F' THEN '1' ELSE '0' END
	  FROM pickdetail PD WITH (NOLOCK)
	  WHERE PD.dropid = @c_dropid         

	 DECLARE CUR_SnoteLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

    SELECT DISTINCT Labelno,CCode
    FROM #SKUNotes

    OPEN CUR_SnoteLoop

    FETCH NEXT FROM CUR_SnoteLoop INTO @c_getlabelno,@c_CCode

    WHILE @@FETCH_STATUS <> -1
    BEGIN

	IF @c_CCode = '1'
	BEGIN
	  SET @c_CCode1 = @c_CCode
	END
	ELSE IF @c_CCode = '2'
	BEGIN
	  SET @c_CCode2 = @c_CCode
	END
	ELSE IF @c_CCode = '3'
	BEGIN
	  SET @c_CCode3 = @c_CCode
	END
	ELSE IF @c_CCode = '4'
	BEGIN
	  SET @c_CCode4 = @c_CCode
	END
	ELSE IF @c_CCode = '5'
	BEGIN
	  SET @c_CCode5 = @c_CCode
	END
	ELSE IF @c_CCode = '6'
	BEGIN
	  SET @c_CCode6 = @c_CCode
	END


	FETCH NEXT FROM CUR_SnoteLoop INTO @c_getlabelno,@c_CCode
	END -- While
	CLOSE CUR_SnoteLoop
	DEALLOCATE CUR_SnoteLoop

   SET @c_GetCol45 = @c_CCode1 + @c_CCode2 + @c_CCode3 + @c_CCode4 + @c_CCode5 + @c_CCode6

  UPDATE #Result
  SET Col32 = CASE WHEN @n_CntLabel <> 0 AND @c_PStatus ='9' THEN CONVERT(NVARCHAR(5),@n_CntLabel) ELSE '' END
      ,Col45 = @c_GetCol45                
	  ,Col46 = @c_Col46                   


     SELECT TOP 1 @n_cntsku = count(DISTINCT PD.SKU),
                @n_SumPickDETQTY = SUM(PD.Qty)
    FROM PACKHEADER PH WITH (NOLOCK) --ON PH.OrderKey = OD.OrderKey
    JOIN PackDetail PD WITH (NOLOCK) ON PD.Pickslipno =PH.Pickslipno 
    WHERE pd.labelno=@c_labelno
    AND PD.CartonNo = convert(INT,@c_Cntno)
    AND PD.StorerKey=@c_storerkey


     SELECT @c_CntRefNo2 = count(DISTINCT PD.RefNo2),
            @c_RefNo2  = PD.RefNo2
     FROM ORDERDETAIL OD WITH (NOLOCK)
     JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = OD.OrderKey
	  JOIN PackDetail PD WITH (NOLOCK) ON PD.Pickslipno =PH.Pickslipno AND PD.Storerkey=OD.Storerkey AND PD.SKU=OD.SKU
	  JOIN SKU S WITH (NOLOCK) ON S.SKU=OD.SKU
                                  AND S.StorerKey = OD.StorerKey
	WHERE pd.labelno=@c_labelno
   AND PD.CartonNo = convert(INT,@c_Cntno)
   AND PD.storerkey = @c_storerkey
   GROUP BY PD.RefNo2

    IF @n_cntsku = 1
    BEGIN
    SELECT DISTINCT @c_ODSKU = OD.SKU,
                    @c_SAltSKU = S.altsku,
                    @c_SDESCR = s.descr--,
                    --@c_RefNo2  = PD.RefNo2
     FROM ORDERDETAIL OD WITH (NOLOCK)
     JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = OD.OrderKey
	  JOIN PackDetail PD WITH (NOLOCK) ON PD.Pickslipno =PH.Pickslipno AND PD.Storerkey=OD.Storerkey AND PD.SKU=OD.SKU
	  JOIN SKU S WITH (NOLOCK) ON S.SKU=OD.SKU
                                  AND S.StorerKey = OD.StorerKey
	WHERE pd.labelno=@c_labelno
   AND PD.CartonNo = convert(INT,@c_Cntno)
   AND PD.storerkey = @c_storerkey

     UPDATE #Result
     SET Col34 = @n_SumPickDETQTY,
         Col35= @c_ODSKU,
         Col36 = @c_SAltSKU,
         Col37=@c_SDESCR

    END
    ELSE
    BEGIN
    UPDATE #Result
     SET Col34 = @n_SumPickDETQTY,
         Col35 = 'MULTI',
         Col36 = '',
         Col37 = 'MULTI'
        --Col38 = 'MULTI'
    END

   IF @c_CntRefNo2 = 1
   BEGIN
     UPDATE #Result
     SET Col38=@c_RefNo2
   END
   ELSE
   BEGIN
     UPDATE #Result
     SET Col38 = 'MULTI'
   END


   FETCH NEXT FROM CUR_RowNoLoop INTO @c_orderkey,@c_CntNo,@c_labelno ,@c_dropid,@c_storerkey     
	END -- While
	CLOSE CUR_RowNoLoop
	DEALLOCATE CUR_RowNoLoop

EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()

   --EXEC isp_InsertTraceInfo
   --   @c_TraceCode = 'BARTENDER',
   --   @c_TraceName = 'isp_BT_Bartender_KR_Shipper_Label_UA',
   --   @c_starttime = @d_Trace_StartTime,
   --   @c_endtime = @d_Trace_EndTime,
   --   @c_step1 = @c_UserName,
   --   @c_step2 = '',
   --   @c_step3 = '',
   --   @c_step4 = '',
   --   @c_step5 = '',
   --   @c_col1 = @c_Sparm1,
   --   @c_col2 = @c_Sparm2,
   --   @c_col3 = @c_Sparm3,
   --   @c_col4 = @c_Sparm4,
   --   @c_col5 = @c_Sparm5,
   --   @b_Success = 1,
   --   @n_Err = 0,
   --   @c_ErrMsg = ''

select * from #result WITH (NOLOCK)

END -- procedure



GO
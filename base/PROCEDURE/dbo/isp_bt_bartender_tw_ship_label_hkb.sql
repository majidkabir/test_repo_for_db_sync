SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/*	Copyright: IDS																					*/
/*	Purpose:	isp_BT_Bartender_TW_Ship_Label_HKB											*/
/*																										*/
/*	Modifications log:																			*/
/*																										*/
/*	Date		  Rev	 Author		Purposes														*/
/*	2023-03-30 1.0	 CSCHONG		Devops Scripts	Combine & Created	(WMS-21995)		*/
/******************************************************************************/

CREATE   PROC	[dbo].[isp_BT_Bartender_TW_Ship_Label_HKB]
(	@c_Sparm01				 NVARCHAR(250),
	@c_Sparm02				 NVARCHAR(250),
	@c_Sparm03				 NVARCHAR(250),
	@c_Sparm04				 NVARCHAR(250),
	@c_Sparm05				 NVARCHAR(250),
	@c_Sparm06				 NVARCHAR(250),
	@c_Sparm07				 NVARCHAR(250),
	@c_Sparm08				 NVARCHAR(250),
	@c_Sparm09				 NVARCHAR(250),
	@c_Sparm10				 NVARCHAR(250),
	@b_debug					 INT = 0
)
AS
BEGIN
	SET NOCOUNT	ON
	SET ANSI_NULLS	OFF
	SET QUOTED_IDENTIFIER OFF
	SET CONCAT_NULL_YIELDS_NULL OFF
  -- SET	ANSI_WARNINGS OFF						--CS03

	DECLARE
		@c_ExternOrderkey	 NVARCHAR(10),
		@c_Sku				 NVARCHAR(20),
		@n_intFlag			 INT,
		@n_CntRec			 INT,
		@c_SQL				 NVARCHAR(4000),
		@c_SQLSORT			 NVARCHAR(4000),
		@c_SQLJOIN			 NVARCHAR(4000),
		@n_totalcase		 INT,
		@n_sequence			 INT,
		@c_skugroup			 NVARCHAR(10),
		@n_CntSku			 INT,
		@n_TTLQty			 INT


  DECLARE  @d_Trace_StartTime	 DATETIME,
			  @d_Trace_EndTime	 DATETIME,
			  @c_Trace_ModuleName NVARCHAR(20),
			  @d_Trace_Step1		 DATETIME,
			  @c_Trace_Step1		 NVARCHAR(20),
			  @c_UserName			 NVARCHAR(20)

	SET @d_Trace_StartTime = GETDATE()
	SET @c_Trace_ModuleName	= ''

	 -- SET RowNo = 0
	 SET @c_SQL	= ''
	 SET @c_Sku	= ''
	 SET @c_skugroup = ''
	 SET @n_totalcase	= 0
	 SET @n_sequence	= 1
	 SET @n_CntSku	= 1
	 SET @n_TTLQty	= 0

	 CREATE TABLE [#Result]	(
		[ID]	  [INT] IDENTITY(1,1) NOT NULL,
		[Col01] [NVARCHAR] (80)	NULL,
		[Col02] [NVARCHAR] (80)	NULL,
		[Col03] [NVARCHAR] (80)	NULL,
		[Col04] [NVARCHAR] (80)	NULL,
		[Col05] [NVARCHAR] (80)	NULL,
		[Col06] [NVARCHAR] (80)	NULL,
		[Col07] [NVARCHAR] (80)	NULL,
		[Col08] [NVARCHAR] (80)	NULL,
		[Col09] [NVARCHAR] (80)	NULL,
		[Col10] [NVARCHAR] (80)	NULL,
		[Col11] [NVARCHAR] (80)	NULL,
		[Col12] [NVARCHAR] (80)	NULL,
		[Col13] [NVARCHAR] (80)	NULL,
		[Col14] [NVARCHAR] (80)	NULL,
		[Col15] [NVARCHAR] (80)	NULL,
		[Col16] [NVARCHAR] (80)	NULL,
		[Col17] [NVARCHAR] (80)	NULL,
		[Col18] [NVARCHAR] (80)	NULL,
		[Col19] [NVARCHAR] (80)	NULL,
		[Col20] [NVARCHAR] (80)	NULL,
		[Col21] [NVARCHAR] (80)	NULL,
		[Col22] [NVARCHAR] (80)	NULL,
		[Col23] [NVARCHAR] (80)	NULL,
		[Col24] [NVARCHAR] (80)	NULL,
		[Col25] [NVARCHAR] (80)	NULL,
		[Col26] [NVARCHAR] (80)	NULL,
		[Col27] [NVARCHAR] (80)	NULL,
		[Col28] [NVARCHAR] (80)	NULL,
		[Col29] [NVARCHAR] (80)	NULL,
		[Col30] [NVARCHAR] (80)	NULL,
		[Col31] [NVARCHAR] (80)	NULL,
		[Col32] [NVARCHAR] (80)	NULL,
		[Col33] [NVARCHAR] (80)	NULL,
		[Col34] [NVARCHAR] (80)	NULL,
		[Col35] [NVARCHAR] (80)	NULL,
		[Col36] [NVARCHAR] (80)	NULL,
		[Col37] [NVARCHAR] (80)	NULL,
		[Col38] [NVARCHAR] (80)	NULL,
		[Col39] [NVARCHAR] (80)	NULL,
		[Col40] [NVARCHAR] (80)	NULL,
		[Col41] [NVARCHAR] (80)	NULL,
		[Col42] [NVARCHAR] (80)	NULL,
		[Col43] [NVARCHAR] (80)	NULL,
		[Col44] [NVARCHAR] (80)	NULL,
		[Col45] [NVARCHAR] (80)	NULL,
		[Col46] [NVARCHAR] (80)	NULL,
		[Col47] [NVARCHAR] (80)	NULL,
		[Col48] [NVARCHAR] (80)	NULL,
		[Col49] [NVARCHAR] (80)	NULL,
		[Col50] [NVARCHAR] (80)	NULL,
		[Col51] [NVARCHAR] (80)	NULL,
		[Col52] [NVARCHAR] (80)	NULL,
		[Col53] [NVARCHAR] (80)	NULL,
		[Col54] [NVARCHAR] (80)	NULL,
		[Col55] [NVARCHAR] (80)	NULL,
		[Col56] [NVARCHAR] (80)	NULL,
		[Col57] [NVARCHAR] (80)	NULL,
		[Col58] [NVARCHAR] (80)	NULL,
		[Col59] [NVARCHAR] (80)	NULL,
		[Col60] [NVARCHAR] (80)	NULL
	  )

	  INSERT	INTO #Result (Col01,Col02,Col03,Col04,Col05,	Col06,Col07,Col08,Col09
				 ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22
				 ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34
				 ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44
				 ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54
				 ,Col55,Col56,Col57,Col58,Col59,Col60)	
  SELECT	DISTINCT	pd.LabelNo,pd.CartonNo,ph.TTLCNTS,replace(CONVERT(NVARCHAR(16),o.editdate,121),'-','/'),o.orderkey,		--5
					o.ExternOrderKey,o.buyerpo, oif.EcomOrderId ,substring(o.notes,1,80),isnull(c.udf05,''), --10
					substring(isnull(c1.long,''),1,80) ,substring(isnull(c1.udf02,''),1,80),substring(isnull(c1.notes,''),1,80),
					substring(isnull(c1.udf03,''),1,80),o.C_Zip,	 --15							 --(CS02)
					CASE WHEN ISNULL(o.C_Company,'')	= '' THEN o.c_contact1 else o.c_company END,o.C_Address1,o.C_Address2,o.C_Address3,o.C_Address4,	  --20
			--		+ CHAR(13) +
					o.C_phone1,o.C_phone2,oif.OrderInfo03,CASE WHEN	oif.OrderInfo03 in ('Y','COD') THEN	oif.PayableAmount	else '' END,
				  SUBSTRING(isnull(c2.description,''),1,80),substring(isnull(c2.notes,''),1,80),substring(isnull(c2.long,''),1,80),
					ISNULL(o.m_address3,''),substring(isnull(c.long,''),1,80),'',	--30
					'','','','','','','','','','',	--40
					'','','','','','','','','','',	--50
					'','','','','','','','','','TW'	 --60
			  --	+ CHAR(13) +
					FROM PackHeader AS ph WITH	(NOLOCK)
					JOIN PackDetail AS pd ON pd.PickSlipNo	= ph.PickSlipNo
					JOIN ORDERS	AS	o WITH (NOLOCK) ON o.OrderKey	= ph.OrderKey 
					JOIN ORDERINFO	AS	oif WITH	(NOLOCK)	ON	oif.OrderKey =	o.OrderKey 
					LEFT JOIN CODELKUP AS c	WITH (NOLOCK) ON c.code=o.shipperkey AND c.LISTNAME='trackno' and	c.code2=o.ordergroup	and c.storerkey =	o.storerkey	 
					LEFT JOIN CODELKUP AS c1 WITH	(NOLOCK)	ON	c1.code=o.shipperkey	AND c1.LISTNAME='COURIERADR' and	c1.code2=''	and c1.storerkey = o.storerkey  
					LEFT JOIN CODELKUP AS c2 WITH	(NOLOCK)	ON	c2.code=oif.StoreName AND c2.LISTNAME='WebsitInfo'	and c2.storerkey = o.storerkey	  
					WHERE	pd.pickslipno = @c_Sparm01	
					AND pd.LabelNo	=@c_Sparm02	
	  


	IF	@b_debug=1
	BEGIN
		PRINT	@c_SQL
	END
	IF	@b_debug=1
	BEGIN
		SELECT *	FROM #Result (nolock)
	END


	EXIT_SP:

	SET @d_Trace_EndTime	= GETDATE()
	SET @c_UserName =	SUSER_SNAME()

	--EXEC isp_InsertTraceInfo
	--	@c_TraceCode =	'BARTENDER',
	--	@c_TraceName =	'isp_BT_Bartender_TW_Ship_Label_HKB',
	--	@c_starttime =	@d_Trace_StartTime,
	--	@c_endtime = @d_Trace_EndTime,
	--	@c_step1	= @c_UserName,
	--	@c_step2	= '',
	--	@c_step3	= '',
	--	@c_step4	= '',
	--	@c_step5	= '',
	--	@c_col1 = @c_Sparm01,
	--	@c_col2 = @c_Sparm02,
	--	@c_col3 = @c_Sparm03,
	--	@c_col4 = @c_Sparm04,
	--	@c_col5 = @c_Sparm05,
	--	@b_Success = 1,
	--	@n_Err =	0,
	--	@c_ErrMsg =	''

	SELECT *	FROM #Result (nolock)

END -- procedure



GO
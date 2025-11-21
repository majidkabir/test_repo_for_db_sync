SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/*	Copyright: LFL																					*/
/*	Purpose:	isp_BT_Bartender_KR_SHIPLBLCJ3_NIKEKR										*/
/*																										*/
/*	Modifications log:																			*/
/*																										*/
/*	Date		  Rev	 Author		Purposes														*/
/*	2021-08-18 1.0	 WLChooi		Created (WMS-17608)										*/
/*	2023-01-30 1.1	 CHONGCS		Devops Scripts	Combine & WMS-21584 (CS01)			*/
/******************************************************************************/
CREATE   PROC	[dbo].[isp_BT_Bartender_KR_SHIPLBLCJ3_NIKEKR]
(	@c_Sparm1				NVARCHAR(250),
	@c_Sparm2				NVARCHAR(250),
	@c_Sparm3				NVARCHAR(250),
	@c_Sparm4				NVARCHAR(250),
	@c_Sparm5				NVARCHAR(250),
	@c_Sparm6				NVARCHAR(250),
	@c_Sparm7				NVARCHAR(250),
	@c_Sparm8				NVARCHAR(250),
	@c_Sparm9				NVARCHAR(250),
	@c_Sparm10				NVARCHAR(250),
	@b_debug					INT =	0
)
AS
BEGIN
	SET NOCOUNT	ON
	SET ANSI_NULLS	OFF
	SET QUOTED_IDENTIFIER OFF
	SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE
		@n_TTLSKUCNT			INT,
		@n_TTLSKUQTY			INT,
		@n_Page					INT,
		@n_ID						INT,
		@n_RID					INT,
		@n_MaxLine				INT,
		@n_MaxLineRec			INT

	DECLARE
		@c_SKU01					NVARCHAR(80) =	'',
		@c_Size01				NVARCHAR(80) =	'',
		@c_Qty01					NVARCHAR(80) =	'',
		@c_SKU02					NVARCHAR(80) =	'',
		@c_Size02				NVARCHAR(80) =	'',
		@c_Qty02					NVARCHAR(80) =	'',
		@c_SKU03					NVARCHAR(80) =	'',
		@c_Size03				NVARCHAR(80) =	'',
		@c_Qty03					NVARCHAR(80) =	'',
		@c_SKU04					NVARCHAR(80) =	'',
		@c_Size04				NVARCHAR(80) =	'',
		@c_Qty04					NVARCHAR(80) =	'',
		@c_SKU05					NVARCHAR(80) =	'',
		@c_Size05				NVARCHAR(80) =	'',
		@c_Qty05					NVARCHAR(80) =	'',
		@c_SKU06					NVARCHAR(80) =	'',
		@c_Size06				NVARCHAR(80) =	'',
		@c_Qty06					NVARCHAR(80) =	'',
		@c_SKU07					NVARCHAR(80) =	'',
		@c_Size07				NVARCHAR(80) =	'',
		@c_Qty07					NVARCHAR(80) =	'',
		@c_SKU08					NVARCHAR(80) =	'',
		@c_Size08				NVARCHAR(80) =	'',
		@c_Qty08					NVARCHAR(80) =	'',
		@c_SKU09					NVARCHAR(80) =	'',
		@c_Size09				NVARCHAR(80) =	'',
		@c_Qty09					NVARCHAR(80) =	'',
		@c_SKU10					NVARCHAR(80) =	'',
		@c_Size10				NVARCHAR(80) =	'',
		@c_Qty10					NVARCHAR(80) =	'',
		@c_SKU					NVARCHAR(80) =	'',
		@c_Size					NVARCHAR(80) =	'',
		@c_Qty					NVARCHAR(80) =	''

	DECLARE	@d_Trace_StartTime  DATETIME,
				@d_Trace_EndTime	  DATETIME,
				@c_Trace_ModuleName NVARCHAR(20),
				@d_Trace_Step1		  DATETIME,
				@c_Trace_Step1		  NVARCHAR(20),
				@c_UserName			  NVARCHAR(20),
				@c_ExecStatements	  NVARCHAR(4000),
				@c_ExecArguments	  NVARCHAR(4000),
				@c_SQL				  NVARCHAR(4000),
				@c_SQLSORT			  NVARCHAR(4000),
				@c_SQLJOIN			  NVARCHAR(4000),
				@n_TTLpage			  INT,
				@c_LabelNo			  NVARCHAR(20),
				@c_Pickslipno		  NVARCHAR(10),
				@n_CartonNo			  INT,
				@n_TotalQty			  INT,
				@c_TrackingNo		  NVARCHAR(50)

	DECLARE @n_CntRec				  INT,
			  @n_CurrentPage		  INT,
			  @n_intFlag			  INT,
			  @n_MaxCtn				  INT,
			  @n_GetCartonNo		  INT

	SET @n_CurrentPage =	1
	SET @n_TTLpage	= 1
	SET @n_MaxLine	= 10
	SET @n_CntRec = 1
	SET @n_intFlag	= 1

	SET @d_Trace_StartTime = GETDATE()
	SET @c_Trace_ModuleName	= ''

	 -- SET RowNo = 0
	SET @c_SQL = ''

	CREATE TABLE [#Result] (
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

	CREATE TABLE [#TMP_PACKDETAIL] (
		[ID]							[INT]	IDENTITY(1,1) NOT	NULL,
		[Pickslipno]				[NVARCHAR] (20) NULL,
		[Labelno]					[NVARCHAR] (20) NULL,
		[LabelLineno]				[NVARCHAR] (10) NULL,
		[SKU]							[NVARCHAR] (80) NULL,
		[Size]						[NVARCHAR] (20) NULL,
		[Qty]							[NVARCHAR] (10) NULL,
		[Retrieve]					[NVARCHAR] (1)	DEFAULT 'N')

	SELECT @n_GetCartonNo =	CartonNo
	FROM PACKDETAIL (NOLOCK)
	WHERE	Pickslipno = @c_Sparm1 AND	LabelNo = @c_Sparm2

	SET @c_SQLJOIN	= + '	SELECT DISTINCT OH.Consigneekey,	TRIM(ISNULL(OH.C_Contact1,'''')), TRIM(ISNULL(OH.C_Company,'''')), TRIM(ISNULL(OH.C_Address1,'''')), TRIM(ISNULL(OH.C_Address2,'''')),	' + CHAR(13) --5
						  + '	TRIM(ISNULL(OH.C_Address3,'''')), TRIM(ISNULL(OH.C_Address4,'''')), TRIM(ISNULL(OH.C_City,'''')), TRIM(ISNULL(OH.C_State,'''')),	TRIM(ISNULL(OH.C_Zip,'''')), '  + CHAR(13) --10
						  + '	TRIM(ISNULL(OH.C_Country,'''')),	TRIM(ISNULL(OH.C_Phone1,'''')), TRIM(ISNULL(F.DESCR,'''')),	TRIM(ISNULL(F.Address1,'''')), TRIM(ISNULL(F.Address2,'''')), ' +	CHAR(13)	--15
						  + '	PD.Pickslipno,	PD.LabelNo,	TRIM(ISNULL(F.Contact1,'''')), TRIM(ISNULL(F.Phone1,'''')),	TRIM(ISNULL(OH.IntermodalVehicle,'''')), '  + CHAR(13) --20
						  + '	TRIM(ISNULL(CL.UDF01,'''')), TRIM(ISNULL(CL.UDF02,'''')), TRIM(ISNULL(CL.UDF03,'''')),	TRIM(ISNULL(CL.UDF04,'''')), PD.Cartonno,	' + CHAR(13) --25
						  + '	'''',	'''',	'''',	'''',	'''',	'	+ CHAR(13) --30
						  + '	'''',	'''',	'''',	'''',	'''',	'''',	'''',	'''',	'''',	'''',	'	+ CHAR(13) --40
						  + '	'''',	'''',	'''',	'''',	'''',	'''',	'''',	'''',	'''',	'''',	'	+ CHAR(13) --50
						  + '	'''',	'''',	'''',	'''',	'''',	'''',	'''',	'''',	'''',	''KR'' '	  --60
						  + CHAR(13) +
						  + '	FROM PACKDETAIL PD WITH	(NOLOCK)' +	CHAR(13)
						  + '	JOIN PACKHEADER PH WITH	(NOLOCK)	ON	PD.Pickslipno = PH.Pickslipno	' + CHAR(13)
						  + '	JOIN ORDERS	OH	WITH (NOLOCK) ON OH.Orderkey = PH.Orderkey '	  + CHAR(13)
						  + '	JOIN FACILITY F WITH	(NOLOCK)	ON	F.Facility = OH.Facility '	  + CHAR(13)
						  + '	LEFT JOIN CODELKUP CL WITH	(NOLOCK)	ON	CL.LISTNAME	= ''NKCARRIER'' AND CL.Storerkey	= OH.Storerkey'	+ CHAR(13)
						  + '												  AND	CL.Long = OH.Consigneekey AND	CL.Code2	= OH.IntermodalVehicle '	+ CHAR(13)
						  + '	WHERE	PD.Pickslipno =  @c_Sparm1	' + CHAR(13)
						  + '	AND PD.LabelNo	=	@c_Sparm2 '

	IF	@b_debug=1
	BEGIN
		PRINT	@c_SQLJOIN
	END

	SET @c_SQL='INSERT INTO	#Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'	+ CHAR(13) +
				 +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'	+ CHAR(13) +
				 +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +
				 +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'	+ CHAR(13) +
				 +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+	CHAR(13)	+
				 +',Col55,Col56,Col57,Col58,Col59,Col60) '

	SET @c_SQL = @c_SQL + @c_SQLJOIN


	SET @c_ExecArguments	=	  N'	@c_Sparm1			 NVARCHAR(80) '
									 +	',	@c_Sparm2			 NVARCHAR(80) '
									 +	',	@c_Sparm3			 NVARCHAR(80) '

	EXEC sp_ExecuteSql	  @c_SQL
								, @c_ExecArguments
								, @c_Sparm1
								, @c_Sparm2
								, @c_Sparm3

	DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD	READ_ONLY FOR
	SELECT DISTINCT @c_Sparm2,	Col16, CAST(Col25	AS	INT)
	FROM #Result
	ORDER	BY	Col16, CAST(Col25	AS	INT)

	OPEN CUR_RowNoLoop

	FETCH	NEXT FROM CUR_RowNoLoop	INTO @c_LabelNo, @c_Pickslipno, @n_CartonNo

	WHILE	@@FETCH_STATUS	<>	-1
	BEGIN
		INSERT INTO	#TMP_PACKDETAIL(Pickslipno, Labelno, LabelLineno
										  , SKU,	Size,	Qty, Retrieve)
		SELECT @c_Pickslipno, @c_LabelNo, PD.LabelLine
			  , TRIM(ISNULL(P.PackUOM3,'')) + TRIM(ISNULL(S.BUSR7,'')) + TRIM(PD.SKU),	TRIM(ISNULL(S.Size,''))	+ '01000', SUM(PD.Qty),	'N'	 --CS01
		FROM PACKHEADER PH WITH	(NOLOCK)
		JOIN PACKDETAIL PD WITH	(NOLOCK)	ON	PH.PickSlipNo = PD.Pickslipno
		JOIN SKU	S WITH (NOLOCK) ON S.Sku =	PD.SKU AND S.Storerkey = PH.Storerkey
		--OUTER APPLY (SELECT TOP 1 S1.Size																								 --CS01 S
		--					FROM SKU	S1	(NOLOCK)
		--					JOIN SKU	S2	(NOLOCK)	ON	S1.ALTSKU =	S2.ALTSKU
		--					WHERE	S1.StorerKey =	'NIKEKRB'
		--					AND S2.StorerKey = PH.StorerKey
		--					AND S2.SKU = S.SKU )	AS	SKU																					  --CS01	E
		JOIN PACK P	WITH (NOLOCK) ON S.PACKKey	= P.PackKey
		WHERE	PD.PickSlipNo = @c_Pickslipno
		AND PD.CartonNo =	CAST(@n_CartonNo AS INT)
		AND PD.LabelNo	= @c_LabelNo
		GROUP	BY	PD.LabelLine, TRIM(ISNULL(P.PackUOM3,''))	+ TRIM(ISNULL(S.BUSR7,''))	+ TRIM(PD.SKU), TRIM(ISNULL(S.Size,'')) +	'01000'	 --CS01
		ORDER	BY	CAST(PD.LabelLine	AS	INT)

		SET @c_SKU01  = ''
		SET @c_Size01 = ''
		SET @c_Qty01  = ''
		SET @c_SKU02  = ''
		SET @c_Size02 = ''
		SET @c_Qty02  = ''
		SET @c_SKU03  = ''
		SET @c_Size03 = ''
		SET @c_Qty03  = ''
		SET @c_SKU04  = ''
		SET @c_Size04 = ''
		SET @c_Qty04  = ''
		SET @c_SKU05  = ''
		SET @c_Size05 = ''
		SET @c_Qty05  = ''
		SET @c_SKU06  = ''
		SET @c_Size06 = ''
		SET @c_Qty06  = ''
		SET @c_SKU07  = ''
		SET @c_Size07 = ''
		SET @c_Qty07  = ''
		SET @c_SKU08  = ''
		SET @c_Size08 = ''
		SET @c_Qty08  = ''
		SET @c_SKU09  = ''
		SET @c_Size09 = ''
		SET @c_Qty09  = ''
		SET @c_SKU10  = ''
		SET @c_Size10 = ''
		SET @c_Qty10  = ''

		IF	@b_debug	= 1
			SELECT *	FROM #TMP_PACKDETAIL

		SELECT @n_CntRec = COUNT (1)
		FROM #TMP_PACKDETAIL
		WHERE	Pickslipno = @c_Pickslipno
		AND LabelNo	= @c_LabelNo
		AND Retrieve =	'N'

		SET @n_TTLpage	=	FLOOR(@n_CntRec /	@n_MaxLine ) +	CASE WHEN @n_CntRec % @n_MaxLine	> 0 THEN	1 ELSE 0	END

		WHILE	@n_intFlag <= @n_CntRec
		BEGIN
			IF	@n_intFlag > @n_MaxLine	AND (@n_intFlag %	@n_MaxLine)	= 1
			BEGIN
				SET @n_CurrentPage =	@n_CurrentPage	+ 1

				IF	(@n_CurrentPage >	@n_TTLpage)
				BEGIN
					BREAK;
				END

				INSERT INTO	#Result (Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09
			  ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22
			  ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34
			  ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44
			  ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54
			  ,Col55,Col56,Col57,Col58,Col59,Col60)
				SELECT TOP 1 Col01,Col02,Col03,Col04,Col05,Col06,Col07,Col08,Col09,Col10,
								 Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,
								 Col21,Col22,Col23,Col24,Col25,'','','','','',
								 '','','','','', '','','','','',
								 '','','','','', '','','','','',
								 '','','','','', '','','','',Col60
				FROM #Result WHERE Col16 <> ''

				SET @c_SKU01  = ''
				SET @c_Size01 = ''
				SET @c_Qty01  = ''
				SET @c_SKU02  = ''
				SET @c_Size02 = ''
				SET @c_Qty02  = ''
				SET @c_SKU03  = ''
				SET @c_Size03 = ''
				SET @c_Qty03  = ''
				SET @c_SKU04  = ''
				SET @c_Size04 = ''
				SET @c_Qty04  = ''
				SET @c_SKU05  = ''
				SET @c_Size05 = ''
				SET @c_Qty05  = ''
				SET @c_SKU06  = ''
				SET @c_Size06 = ''
				SET @c_Qty06  = ''
				SET @c_SKU07  = ''
				SET @c_Size07 = ''
				SET @c_Qty07  = ''
				SET @c_SKU08  = ''
				SET @c_Size08 = ''
				SET @c_Qty08  = ''
				SET @c_SKU09  = ''
				SET @c_Size09 = ''
				SET @c_Qty09  = ''
				SET @c_SKU10  = ''
				SET @c_Size10 = ''
				SET @c_Qty10  = ''
			END

			SELECT	@c_SKU	= SKU
					 ,	@c_Size	= Size
					 ,	@c_Qty	= Qty
			 FROM	#TMP_PACKDETAIL
			 WHERE ID =	@n_intFlag

			 IF (@n_intFlag %	@n_MaxLine)	= 1
			 BEGIN
				 SET @c_SKU01		 =	@c_SKU
				 SET @c_Size01		 =	@c_Size
				 SET @c_Qty01		 =	@c_Qty
			 END
			 ELSE	IF	(@n_intFlag	% @n_MaxLine) = 2
			 BEGIN
				 SET @c_SKU02		 =	@c_SKU
				 SET @c_Size02		 =	@c_Size
				 SET @c_Qty02		 =	@c_Qty
			 END
			 ELSE	IF	(@n_intFlag	% @n_MaxLine) = 3
			 BEGIN
				 SET @c_SKU03		 =	@c_SKU
				 SET @c_Size03		 =	@c_Size
				 SET @c_Qty03		 =	@c_Qty
			 END
			 ELSE	IF	(@n_intFlag	% @n_MaxLine) = 4
			 BEGIN
				 SET @c_SKU04		 =	@c_SKU
				 SET @c_Size04		 =	@c_Size
				 SET @c_Qty04		 =	@c_Qty
			 END
			 ELSE	IF	(@n_intFlag	% @n_MaxLine) = 5
			 BEGIN
				 SET @c_SKU05		 =	@c_SKU
				 SET @c_Size05		 =	@c_Size
				 SET @c_Qty05		 =	@c_Qty
			 END
			 ELSE	IF	(@n_intFlag	% @n_MaxLine) = 6
			 BEGIN
				 SET @c_SKU06		 =	@c_SKU
				 SET @c_Size06		 =	@c_Size
				 SET @c_Qty06		 =	@c_Qty
			 END
			 ELSE	IF	(@n_intFlag	% @n_MaxLine) = 7
			 BEGIN
				 SET @c_SKU07		 =	@c_SKU
				 SET @c_Size07		 =	@c_Size
				 SET @c_Qty07		 =	@c_Qty
			 END
			 ELSE	IF	(@n_intFlag	% @n_MaxLine) = 8
			 BEGIN
				 SET @c_SKU08		 =	@c_SKU
				 SET @c_Size08		 =	@c_Size
				 SET @c_Qty08		 =	@c_Qty
			 END
			 ELSE	IF	(@n_intFlag	% @n_MaxLine) = 9
			 BEGIN
				 SET @c_SKU09		 =	@c_SKU
				 SET @c_Size09		 =	@c_Size
				 SET @c_Qty09		 =	@c_Qty
			 END
			 ELSE	IF	(@n_intFlag	% @n_MaxLine) = 0
			 BEGIN
				 SET @c_SKU10		 =	@c_SKU
				 SET @c_Size10		 =	@c_Size
				 SET @c_Qty10		 =	@c_Qty
			 END

			 UPDATE #Result
			 SET	 Col29 =	@c_SKU01
				  , Col30 =	@c_Qty01
				  , Col31 =	@c_Size01
				  , Col32 =	@c_SKU02
				  , Col33 =	@c_Qty02
				  , Col34 =	@c_Size02
				  , Col35 =	@c_SKU03
				  , Col36 =	@c_Qty03
				  , Col37 =	@c_Size03
				  , Col38 =	@c_SKU04
				  , Col39 =	@c_Qty04
				  , Col40 =	@c_Size04
				  , Col41 =	@c_SKU05
				  , Col42 =	@c_Qty05
				  , Col43 =	@c_Size05
				  , Col44 =	@c_SKU06
				  , Col45 =	@c_Qty06
				  , Col46 =	@c_Size06
				  , Col47 =	@c_SKU07
				  , Col48 =	@c_Qty07
				  , Col49 =	@c_Size07
				  , Col50 =	@c_SKU08
				  , Col51 =	@c_Qty08
				  , Col52 =	@c_Size08
				  , Col53 =	@c_SKU09
				  , Col54 =	@c_Qty09
				  , Col55 =	@c_Size09
				  , Col56 =	@c_SKU10
				  , Col57 =	@c_Qty10
				  , Col58 =	@c_Size10
			WHERE	ID	= @n_CurrentPage AND	Col16	<>	''

			UPDATE #TMP_PACKDETAIL
			SET Retrieve =	'Y'
			WHERE	ID	= @n_intFlag

			SET @n_intFlag	= @n_intFlag +	1

			IF	@n_intFlag > @n_CntRec
			BEGIN
				BREAK;
			END
		END

		FETCH	NEXT FROM CUR_RowNoLoop	INTO @c_LabelNo, @c_Pickslipno, @n_CartonNo
	END
	CLOSE	CUR_RowNoLoop
	DEALLOCATE CUR_RowNoLoop

	IF	EXISTS (SELECT	1 FROM PACKHEADER	(NOLOCK)	WHERE	Pickslipno = @c_Sparm1 AND	[Status]	= '9')
	BEGIN
		SELECT @n_MaxCtn = MAX(PD.CartonNo)
		FROM PACKDETAIL PD (NOLOCK)
		WHERE	Pickslipno = @c_Sparm1
	END

	SELECT @n_TotalQty	= SUM(PIF.Qty)
		  , @c_TrackingNo	= MAX(PIF.TrackingNo)
	FROM PACKINFO PIF	(NOLOCK)
	WHERE	PIF.PickSlipNo	= @c_Sparm1	AND PIF.CartonNo = @n_GetCartonNo

	UPDATE #Result
	SET Col26 =	CASE WHEN ISNUMERIC(@n_MaxCtn) =	1 THEN CAST(@n_MaxCtn AS NVARCHAR) ELSE '' END
	  , Col27 =	@n_TotalQty
	  , Col28 =	@c_TrackingNo
	WHERE	Col16	<>	''

	SELECT *	from #result WITH	(NOLOCK)

EXIT_SP:
END -- procedure

GO
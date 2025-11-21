SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/    
/* Copyright: LFL                                                             */    
/* Purpose: isp_BT_Bartender_US_GNCTN_LVCL11                                  */    
/*                                                                            */    
/* Modifications log:                                                         */    
/*                                                                            */    
/* Date        Rev  Author     Purposes                                       */    
/* 10 JUNE 2024 1.0  Sundar    Created                          */    

/******************************************************************************/    
    
CREATE   PROC [dbo].[isp_BT_Bartender_US_GNCTN_LVCL11]
(
   @c_Sparm1  NVARCHAR(250)
 , @c_Sparm2  NVARCHAR(250)
 , @c_Sparm3  NVARCHAR(250)
 , @c_Sparm4  NVARCHAR(250)
 , @c_Sparm5  NVARCHAR(250)
 , @c_Sparm6  NVARCHAR(250)
 , @c_Sparm7  NVARCHAR(250)
 , @c_Sparm8  NVARCHAR(250)
 , @c_Sparm9  NVARCHAR(250)
 , @c_Sparm10 NVARCHAR(250)
 , @b_debug   INT = 0
)
AS  
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @c_ExecStatements NVARCHAR(MAX)    
         , @c_ExecArguments  NVARCHAR(MAX)    
         , @c_SQLJOIN        NVARCHAR(MAX)    
         , @c_SQL            NVARCHAR(MAX)    
         , @c_Condition      NVARCHAR(MAX)    
         , @c_SQLJOINTable   NVARCHAR(MAX)       
         , @c_Orderkey       NVARCHAR(10)    
    
   DECLARE @d_Trace_StartTime  DATETIME    
         , @d_Trace_EndTime    DATETIME    
         , @c_Trace_ModuleName NVARCHAR(20)    
         , @d_Trace_Step1      DATETIME    
         , @c_Trace_Step1      NVARCHAR(20)    
         , @c_UserName         NVARCHAR(50)    
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = N''    
    
   CREATE TABLE [#Result]    
   (    
      [ID]    [INT]          IDENTITY(1, 1) NOT NULL    
    , [Col01] [NVARCHAR](80) NULL    
    , [Col02] [NVARCHAR](80) NULL    
    , [Col03] [NVARCHAR](80) NULL    
    , [Col04] [NVARCHAR](80) NULL    
    , [Col05] [NVARCHAR](80) NULL    
    , [Col06] [NVARCHAR](80) NULL    
    , [Col07] [NVARCHAR](80) NULL    
    , [Col08] [NVARCHAR](80) NULL    
    , [Col09] [NVARCHAR](80) NULL    
    , [Col10] [NVARCHAR](80) NULL    
    , [Col11] [NVARCHAR](80) NULL    
    , [Col12] [NVARCHAR](80) NULL    
    , [Col13] [NVARCHAR](80) NULL    
    , [Col14] [NVARCHAR](80) NULL    
    , [Col15] [NVARCHAR](80) NULL    
    , [Col16] [NVARCHAR](80) NULL    
    , [Col17] [NVARCHAR](80) NULL    
    , [Col18] [NVARCHAR](80) NULL    
    , [Col19] [NVARCHAR](80) NULL    
    , [Col20] [NVARCHAR](80) NULL    
    , [Col21] [NVARCHAR](80) NULL    
    , [Col22] [NVARCHAR](80) NULL    
    , [Col23] [NVARCHAR](80) NULL    
    , [Col24] [NVARCHAR](80) NULL    
    , [Col25] [NVARCHAR](80) NULL    
    , [Col26] [NVARCHAR](80) NULL    
    , [Col27] [NVARCHAR](80) NULL    
    , [Col28] [NVARCHAR](80) NULL    
    , [Col29] [NVARCHAR](80) NULL    
    , [Col30] [NVARCHAR](80) NULL    
    , [Col31] [NVARCHAR](80) NULL    
    , [Col32] [NVARCHAR](80) NULL    
    , [Col33] [NVARCHAR](80) NULL    
    , [Col34] [NVARCHAR](80) NULL    
    , [Col35] [NVARCHAR](80) NULL    
    , [Col36] [NVARCHAR](80) NULL    
    , [Col37] [NVARCHAR](80) NULL    
    , [Col38] [NVARCHAR](80) NULL    
    , [Col39] [NVARCHAR](80) NULL    
    , [Col40] [NVARCHAR](80) NULL    
    , [Col41] [NVARCHAR](80) NULL    
    , [Col42] [NVARCHAR](80) NULL    
    , [Col43] [NVARCHAR](80) NULL    
    , [Col44] [NVARCHAR](80) NULL   
    , [Col45] [NVARCHAR](80) NULL    
    , [Col46] [NVARCHAR](80) NULL    
    , [Col47] [NVARCHAR](80) NULL    
    , [Col48] [NVARCHAR](80) NULL    
    , [Col49] [NVARCHAR](80) NULL    
    , [Col50] [NVARCHAR](80) NULL    
    , [Col51] [NVARCHAR](80) NULL    
    , [Col52] [NVARCHAR](80) NULL    
    , [Col53] [NVARCHAR](80) NULL    
    , [Col54] [NVARCHAR](80) NULL    
    , [Col55] [NVARCHAR](80) NULL    
    , [Col56] [NVARCHAR](80) NULL    
    , [Col57] [NVARCHAR](80) NULL    
    , [Col58] [NVARCHAR](80) NULL    
    , [Col59] [NVARCHAR](80) NULL    
    , [Col60] [NVARCHAR](80) NULL    
   )    

   SET @c_SQLJOIN = 	N' SELECT DISTINCT '+CHAR(13)
+N' P.[1], P.[2], P.[3], P.[4], P.[5], P.[6], P.[7], P.[8], P.[9], P.[10],'+CHAR(13)
+N' 	P.[11], P.[12], P.[13], P.[14], P.[15], P.[16], P.[17], P.[18], P.[19], P.[20],'+CHAR(13)
	+N' P.[21], P.[22], P.[23], P.[24], P.[25],'+CHAR(13)
	+N' P.TOTALSQTY,P.PO,P.PALLETTYPE,P.CAR,'+CHAR(13)
	+N' P.SKID,P.PALLETSTACK,LTRIM(SUBSTRING(P.CUSTOMER,LEN(P.CUSTOMER)-5,5)),'+CHAR(13)
	+N' P.CONTACT,P.DEPT,P.CARTONID,'+CHAR(13)
	+N' P.SEQ,P.COUNTS,P.BOL,P.PRO,P.OCN,'+CHAR(13)
	+N' CASE WHEN (P.SPECIALINS=''XDC'') OR(P.SPECIALINS LIKE ''HH%'')'+CHAR(13)
	+N' THEN P.SPECIALINS ELSE '''' END AS SPECIALINS,'+CHAR(13)
	+N' CASE WHEN (P.SPECIALINS=''XDC'') OR(P.SPECIALINS LIKE ''HH%'')'+CHAR(13)
	+N' THEN ''HANGERS'' ELSE '''' END AS H,'+CHAR(13)
	+N' CASE WHEN (P.SPECIALINS=''XDC'') OR(P.SPECIALINS LIKE ''HH%'')'+CHAR(13)
	+N' THEN ''NEWFLOW'' ELSE '''' END AS N,'+CHAR(13)
	+N' CASE WHEN (P.SPECIALINS=''XDC'') OR(P.SPECIALINS LIKE ''HH%'')'+CHAR(13)
	+N' THEN ''OLPL'' ELSE '''' END AS O,'+CHAR(13)
	+N' P.CARTONID AS SSCC,'+CHAR(13)
         +N' '''', '''', '''', '''', '''', '+CHAR(13) --50
        +N' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''' '+CHAR(13)  --60
	+N' FROM ('+CHAR(13)
	+N' SELECT CONCAT (S.STYLE,''#'',CONCAT(S.SIZE,''x'',S.Measurement),''*'',PD. QTY,''$'')  AS ITEM,'+CHAR(13)
	+N' PD.PICKSLIPNO,O.BuyerPO AS PO,''''AS PALLETTYPE,M.CarrierKey AS CAR,''''AS SKID,''''AS PALLETSTACK,'+CHAR(13)
	+N' O.ConsigneeKey AS CUSTOMER,'+CHAR(13)
	+N' CASE WHEN O.M_CONTACT1 IS NOT NULL THEN O.M_CONTACT1 ELSE O.C_CONTACT1 END AS CONTACT,'+CHAR(13)
	+N' S.SKUGROUP AS DEPT,PI.UCCNo AS CARTONID,COUNT(DISTINCT PD.CARTONNO)AS SEQ,PH.TTLCNTS AS COUNTS,'+CHAR(13)
	+N' M.MBOLKEY AS BOL ,M.Carrieragent AS PRO,O.ExternOrderKey AS OCN,WD.WkOrdUdef2 AS SPECIALINS,'+CHAR(13)
	+N' O.BillToKey,S.SKUGROUP,PI.Qty AS TOTALSQTY,'+CHAR(13)
	+N' ROWNUMBER = Row_Number() over (order by PD.SKU,PD.PICKSLIPNO) '+CHAR(13)
	+N' FROM ORDERS O '+CHAR(13)
	+N' LEFT JOIN ORDERINFO OI ON OI.ORDERKEY=O.ORDERKEY'+CHAR(13)
	+N' INNER JOIN ORDERDETAIL OD ON O.ORDERKEY=OD.ORDERKEY'+CHAR(13)
	+N' INNER JOIN PACKHEADER PH ON PH.ORDERKEY=O.ORDERKEY '+CHAR(13)
	+N' INNER JOIN PACKDETAIL PD  ON PD.PICKSLIPNO=PH.PICKSLIPNO'+CHAR(13)
	+N' INNER JOIN PACKINFO PI ON PI.PickSlipNo=PD.PICKSLIPNO AND PI.CartonNo =PD.CartonNo'+CHAR(13)
	+N' INNER JOIN SKU S ON S.SKU=PD.SKU AND S.STORERKEY=O.STORERKEY'+CHAR(13)
	+N' INNER JOIN MBOLDETAIL MD ON MD.OrderKey=O.ORDERKEY'+CHAR(13)
	+N' INNER JOIN MBOL M ON M.MBOLKEY=MD.MBOLKEY'+CHAR(13)
	+N' LEFT  JOIN WORKORDER W ON W.ExternWorkOrderKey=O.OrderKey'+CHAR(13)
	+N' LEFT  JOIN WORKORDERDETAIL WD ON WD.ExternWorkOrderKey =O.ExternOrderKey '+CHAR(13)
	+N' --AND WD.EXTERNLINENO =OD.OrderLineNumber '+CHAR(13)
--	+N' --WHERE O.ORDERKEY=''0000008207'' '+CHAR(13)
	--+N' WHERE O.ORDERKEY=@c_Sparm1 '+CHAR(13)
	+ N'	WHERE PD.PickSlipNo=@c_Sparm1 AND PD.LabelNo=@c_Sparm2 ' + CHAR(13)
	+N' GROUP BY S.STYLE,PD.QTY,PD.PICKSLIPNO,PD.SKU,O.BUYERPO,M.CarrierKey,'+CHAR(13)
	+N' O.ConsigneeKey,O.BillToKey,S.SKUGROUP,M.MBOLKEY,PH.TTLCNTS,PI.UCCNo,PI.QTY,SIZE,S.Measurement,'+CHAR(13)
	+N' O.M_Contact1,O.C_contact1,OI.Notes,M.Carrieragent,O.ExternOrderKey,'+CHAR(13)
	+N' WD.WkOrdUdef2'+CHAR(13)
	+N' )A'+CHAR(13)
	+N' PIVOT  '+CHAR(13)
	+N' (MAX(ITEM) FOR ROWNUMBER  in ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12],[13],[14],[15],'+CHAR(13)
	+N' [16],[17],[18],[19],[20],[21],[22],[23],[24],[25])) P '+CHAR(13)

	
	
	
	   IF @b_debug = 1    
   BEGIN    
      PRINT @c_SQLJOIN    
   END    
    
   SET @c_SQL = ' INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09' + CHAR(13)    
              + '                     ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22' + CHAR(13)    
              + '                     ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13)    
              + '                     ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44' + CHAR(13)    
              + '                     ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54' + CHAR(13)    
              + '                     ,Col55,Col56,Col57,Col58,Col59,Col60) '    
    
   SET @c_SQL = @c_SQL + @c_SQLJOIN    
    
   SET @c_ExecArguments = N'  @c_Sparm1         NVARCHAR(80)'     
                        + N' ,@c_Sparm2         NVARCHAR(80)'    
                        + N' ,@c_Sparm3         NVARCHAR(80)'     
                        + N' ,@c_Sparm4         NVARCHAR(80)'    
                        + N' ,@c_Sparm5         NVARCHAR(80)'    
    
   EXEC sp_executesql @c_SQL    
                    , @c_ExecArguments    
                    , @c_Sparm1    
                    , @c_Sparm2    
                    , @c_Sparm3    
                    , @c_Sparm4    
                    , @c_Sparm5    

   EXIT_SP:    
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
    
   SELECT *    
   FROM #Result WITH (NOLOCK)    
END -- procedure 

GO
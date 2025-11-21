SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/    
/* Copyright: LFL                                                             */    
/* Purpose: isp_BT_Bartender_US_GNVND_OTSL80                                */    
/*                                                                            */    
/* Modifications log:                                                         */    
/*                                                                            */    
/* Date        Rev  Author     Purposes                                       */    
/* 10 JUNE 2024 1.0  Sundar    Created                          */    

/******************************************************************************/    
    
CREATE  PROC [dbo].[isp_BT_Bartender_US_GNVND_OTSL80]
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

   SET @c_SQLJOIN = 	 N'SELECT DISTINCT '+CHAR(13)
 +N'	F.DESCR,'+CHAR(13)--1
	 +N'F.ADDRESS1,'+CHAR(13)--2
	 +N'F.CITY,'+CHAR(13)--3
	 +N'F.STATE,'+CHAR(13)--4
	 +N'F.ZIP,'+CHAR(13)--5
	 +N'O.C_Company,'+CHAR(13)--6
	 +N'O.C_Address1, '+CHAR(13)--7
	 +N'O.C_Address2, '+CHAR(13)--8
	 +N'O.C_Address3, '+CHAR(13)--9
	 +N'O.C_Address4, '+CHAR(13)--10
	 +N'O.C_City,'+CHAR(13)--11
	 +N'O.C_State,'+CHAR(13)--12
	 +N'O.C_Zip,'+CHAR(13)--13
	 +N'CONCAT(''(420) '',O.C_Zip),'+CHAR(13)--14
	 +N'M.CARRIERKEY,'+CHAR(13)--15
	 +N'M.CARRIERAGENT,'+CHAR(13)--16
	 +N'M.MBOLKEY,'+CHAR(13)--17
	 +N'POD.CARTONNO ,'+CHAR(13)--18
	 +N'MAX(POD.CARTONNO) ,'+CHAR(13)--19
	 +N'O.ExternOrderKey,'+CHAR(13)--20
	 +N'PD.CASEID,'+CHAR(13)--21
	 +N''''', '''', '''', '''','''', '''', '''', '''','''',   '+CHAR(13)--30
     +N''''', '''', '''', '''', '''', '''', '''', '''', '''', '''',  '+CHAR(13)--40
     +N''''', '''', '''', '''', '''', '''', '''', '''', '''', '''', '+CHAR(13) --50
     +N''''', '''', '''', '''', '''', '''', '''', '''', '''', ''''   '+CHAR(13)--60
	 +N'FROM ORDERS O '+CHAR(13)
	 +N'INNER JOIN FACILITY F ON F.Facility=O.Facility'+CHAR(13)
	 +N'INNER JOIN MBOLDETAIL MD ON MD.ORDERKEY=O.ORDERKEY'+CHAR(13)
	 +N'INNER JOIN MBOL M ON M.MBOLKEY=MD.MBOLKEY'+CHAR(13)
	 +N'INNER JOIN ORDERDETAIL OD ON O.ORDERKEY=OD.ORDERKEY'+CHAR(13)
	 +N'INNER JOIN SKU S ON S.SKU=OD.SKU AND O.STORERKEY=S.STORERKEY'+CHAR(13)
	 +N'INNER JOIN PICKDETAIL PD ON S.SKU=OD.SKU AND PD.ORDERKEY=OD.ORDERKEY'+CHAR(13)
	 +N'INNER JOIN PACKHEADER POH ON POH.ORDERKEY=O.ORDERKEY'+CHAR(13)
	 +N'INNER JOIN PACKDETAIL POD ON POD.PICKSLIPNO=POH.PICKSLIPNO AND POD.SKU=PD.SKU'+CHAR(13)
	 --+N'WHERE  O.ORDERKEY=@c_Sparm1'+CHAR(13)
	-- +N'-- WHERE O.ORDERKEY=''0000016294'''+CHAR(13)
	+ N'	WHERE POD.PickSlipNo=@c_Sparm1 AND POD.LabelNo=@c_Sparm2 ' + CHAR(13)
	  +N'GROUP BY F.DESCR,'+CHAR(13)
	 +N'F.ADDRESS1,	F.CITY,	F.STATE,	F.ZIP,	O.C_Company,	O.C_Address1, 	O.C_Address2, '+CHAR(13)
	 +N'O.C_Address3, 	O.C_Address4, 	O.C_City,	O.C_State,	O.C_Zip,		M.CARRIERKEY,'+CHAR(13)
	 +N'M.CARRIERAGENT,	M.MBOLKEY,	S.SKUGROUP,	O.BuyerPO,	POD.CARTONNO ,	O.ExternOrderKey,'+CHAR(13)
	 +N'O.CONSIGNEEKEY,O.M_CONTACT2,O.C_CONTACT2,O.M_CONTACT1,PD.CaseID'+CHAR(13)
	
	
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
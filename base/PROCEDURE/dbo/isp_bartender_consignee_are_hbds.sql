SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/******************************************************************************/
/* Copyright: MAERSK                                                          */
/* Purpose: isp_Bartender_Consignee_ARE_HBDS	                              */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2024-11-05 1.0  BCA117     Created(FCR-1051)			                      */
/******************************************************************************/

CREATE   PROC [dbo].[isp_Bartender_Consignee_ARE_HBDS]
(  @c_Sparm01  NVARCHAR(250),
   @c_Sparm02  NVARCHAR(250),
   @c_Sparm03  NVARCHAR(250),
   @c_Sparm04  NVARCHAR(250),
   @c_Sparm05  NVARCHAR(250),
   @c_Sparm06  NVARCHAR(250),
   @c_Sparm07  NVARCHAR(250),
   @c_Sparm08  NVARCHAR(250),
   @c_Sparm09  NVARCHAR(250),
   @c_Sparm10  NVARCHAR(250),
   @b_debug    INT = 0
)
AS
BEGIN
print '-----isp_Bartender_Consignee_ARE_HBDS----'
print '@c_Sparm01:'+isnull(@c_Sparm01,'')
print '@c_Sparm02:'+isnull(@c_Sparm02,'')
print '@c_Sparm03:'+isnull(@c_Sparm03,'')
print '@c_Sparm04:'+isnull(@c_Sparm04,'')
print '@c_Sparm05:'+isnull(@c_Sparm05,'')
print '@c_Sparm06:'+isnull(@c_Sparm06,'')
print '@c_Sparm07:'+isnull(@c_Sparm07,'')
print '@c_Sparm08:'+isnull(@c_Sparm08,'')
print '@c_Sparm09:'+isnull(@c_Sparm09,'')
print '@c_Sparm10:'+isnull(@c_Sparm10,'')
print '---------------'
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @Description			NVARCHAR(100)
   DECLARE @Address				NVARCHAR(100)
   DECLARE @City				NVARCHAR(100)
   DECLARE @Phone				NVARCHAR(100)
   DECLARE @Contact				NVARCHAR(100)
   DECLARE @C_Address			NVARCHAR(100)
   DECLARE @C_City				NVARCHAR(100)
   DECLARE @C_State				NVARCHAR(100)
   DECLARE @C_Zip				NVARCHAR(100)
   DECLARE @C_Country			NVARCHAR(100)
   DECLARE @C_Phone				NVARCHAR(100)
   DECLARE @DGcontent			NVARCHAR(100)

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

   SELECT TOP 1
       @Description		= ISNULL(FC.Descr,'')
	  ,@Address			= ISNULL(FC.address1,'')+ISNULL(FC.address2,'')+ISNULL(FC.address3,'')+ISNULL(FC.address4,'')
	  ,@City			= ISNULL(FC.City,'')+'-'+ISNULL(FC.Country,'')
      ,@Phone			= 'TEL: '+ISNULL(FC.Phone1,'')+ISNULL(FC.Phone2,'')
      ,@Contact			= ISNULL(OD.C_Contact1,'')
	  ,@C_Address		= ISNULL(OD.C_Address1,'')+ISNULL(OD.C_Address2,'')+ISNULL(OD.C_Address3,'')+ISNULL(OD.C_Address4,'')
      ,@C_City          = ISNULL(OD.C_City,'')
      ,@C_State         = ISNULL(OD.C_State,'')
	  ,@C_Zip  		    = ISNULL(OD.C_Zip,'')
      ,@C_Country       = ISNULL(OD.C_Country,'')
	  ,@C_Phone         = 'Ph: '+ISNULL(OD.C_Phone1,'')
	  ,@DGcontent       = ISNULL(CL.Long,'')
   FROM Orders OD (NOLOCK)
   JOIN FACILITY FC (NOLOCK) ON OD.FACILITY = FC.FACILITY
   LEFT JOIN codelkup CL (NOLOCK) ON CL.listname='LBLCONFIG' AND CL.code=OD.Userdefine04 AND CL.Storerkey=OD.Storerkey
   WHERE OD.OrderKey =  @c_Sparm01

   INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09,Col10
         ,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20
         ,Col21,Col22,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30
         ,Col31,Col32,Col33,Col34,Col35,Col36,Col37,Col38,Col39,Col40
         ,Col41,Col42,Col43,Col44,Col45,Col46,Col47,Col48,Col49,Col50
         ,Col51,Col52,Col53,Col54,Col55,Col56,Col57,Col58,Col59,Col60)

   SELECT ISNULL(@Description,'') AS Col01
         ,ISNULL(@Address,'') AS Col02
         ,ISNULL(@City,'') AS Col03
         ,ISNULL(@Phone,'') AS Col04
         ,ISNULL(@Contact,'') AS Col05
         ,ISNULL(@C_Address,'') AS Col06
         ,ISNULL(@C_City,'') AS Col07
         ,ISNULL(@C_State,'') AS Col08
         ,ISNULL(@C_Zip,'') AS Col09
		 ,ISNULL(@C_Country,'') AS Col010
		 ,ISNULL(@C_Phone,'') AS Col11
		 ,ISNULL(@DGcontent,'') AS Col12
		 ,'' AS Col13,'' AS Col14,'' AS Col15,'' AS Col16,'' AS Col17,'' AS Col18,'' AS Col19,'' AS Col20
         ,'' AS Col21,'' AS Col22,'' AS Col23,'' AS Col24,'' AS Col25,'' AS Col26,'' AS Col27,'' AS Col28,'' AS Col29,'' AS Col30
         ,'' AS Col31,'' AS Col32,'' AS Col33,'' AS Col34,'' AS Col35,'' AS Col36,'' AS Col37,'' AS Col38,'' AS Col39,'' AS Col40
         ,'' AS Col41,'' AS Col42,'' AS Col43,'' AS Col44,'' AS Col45,'' AS Col46,'' AS Col47,'' AS Col48,'' AS Col49,'' AS Col50
         ,'' AS Col51,'' AS Col52,'' AS Col53,'' AS Col54,'' AS Col55,'' AS Col56,'' AS Col57,'' AS Col58,'' AS Col59,'' AS Col60

   SELECT * FROM #Result (nolock)

EXIT_SP:

END -- procedure
GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/******************************************************************************/  
/* Copyright: LFL                                                             */  
/* Purpose: isp_BT_Bartender_ID_CTNLABEL03_Adidas                             */  
/*                                                                            */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2022-11-09 1.0  CSCHONG    Devops Scripts Combine & Created(WMS-20649)     */  
/* 2023-01-12 1.1  CSCHONG    WMS-20649 new field (CS01)                      */
/******************************************************************************/  
  
CREATE    PROC [dbo].[isp_BT_Bartender_ID_CTNLABEL03_Adidas]  
(  @c_Sparm01            NVARCHAR(250),  
   @c_Sparm02            NVARCHAR(250),  
   @c_Sparm03            NVARCHAR(250),  
   @c_Sparm04            NVARCHAR(250),  
   @c_Sparm05            NVARCHAR(250),  
   @c_Sparm06            NVARCHAR(250),  
   @c_Sparm07            NVARCHAR(250),  
   @c_Sparm08            NVARCHAR(250),  
   @c_Sparm09            NVARCHAR(250),  
   @c_Sparm10            NVARCHAR(250),  
   @b_debug              INT = 0  
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
      @n_intFlag         INT,  
      @n_CntRec          INT,  
      @c_SQL             NVARCHAR(4000),  
      @c_SQLSORT         NVARCHAR(4000),  
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_RecType         NVARCHAR(20),  
      @c_storerkey       NVARCHAR(20),  
      @c_ExecStatements  NVARCHAR(4000),  
      @c_ExecArguments   NVARCHAR(4000)  
  
   DECLARE @d_Trace_StartTime   DATETIME,  
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),  
           @d_Trace_Step1      DATETIME,  
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_getordkey        NVARCHAR(20),   --CS01
           @n_sumordqtypick    INT,            --CS01  
           @n_sumordoriqty     INT,            --CS01
           @c_col06            NVARCHAR(80)    --CS01
  
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
  
   -- SET RowNo = 0  
   SET @c_SQL = ''  


    --CS01 S

     SET @c_getordkey =''
     SET @n_sumordoriqty = 0
     SET @n_sumordqtypick = 0
     SET @c_col06 =''

     SELECT @c_getordkey = PH.OrderKey                 
     FROM PACKHEADER PH WITH (NOLOCK) 
     JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo AND PD.Storerkey = PH.Storerkey 
     WHERE PD.storerkey =@c_Sparm01   
     AND PD.Pickslipno = @c_Sparm02   
     AND PD.Cartonno = CAST(@c_Sparm03 as int)    

     SELECT @n_sumordqtypick = SUM(OD.QtyPicked)
           ,@n_sumordoriqty =  SUM(OD.OriginalQty)
     FROM dbo.ORDERDETAIL OD WITH (NOLOCK)
     WHERE OD.OrderKey = @c_getordkey

     IF @n_sumordqtypick < @n_sumordoriqty
     BEGIN
         SET @c_col06 ='Partial'
     ENd
        

    --CS01 E
  
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


 INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09
                                    ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22
                                    ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34
                                    ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44
                                    ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54
                                    ,Col55,Col56,Col57,Col58,Col59,Col60)
  SELECT DISTINCT PH.OrderRefNo + '-' + CAST(PD.Cartonno as NVARCHAR(5)) 
                     ,PH.OrderRefNo + ',' + PH.Orderkey + ',' + PD.LabelNo, PIF.Weight,ISNULL(OIF.EcomOrderId,'')       
                     ,ISNULL(OH.ECOM_Platform,'') , @c_col06, '', '','','',  --CS01
                    + CHAR(13) +  
                      '','','','','','','','','','',   
                    + CHAR(13) +  
                      '','','','','','','','','','',    
                    + CHAR(13) +  
                      '','','','','','','','','','',   
                    + CHAR(13) +  
                      '','','','','','','','','','',   
                    + CHAR(13) +  
                      '','','','','','','','','',''
                      FROM PACKHEADER PH WITH (NOLOCK) 
                      JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo AND PD.Storerkey = PH.Storerkey 
                      JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.Pickslipno = PD.Pickslipno AND PIF.cartonno = PD.cartonno   
                      JOIN ORDERS OH WITH (NOLOCK) on PH.OrderKey = OH.OrderKey and PH.StorerKey=OH.StorerKey  
                      LEFT JOIN ORDERINFO OIF WITH (NOLOCK) on OIF.Orderkey = OH.Orderkey   
                      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'PLATFLKUP' AND C.storerkey = OH.Storerkey and C.code = OH.buyerpo    
                      WHERE PD.storerkey =@c_Sparm01   
                      AND PD.Pickslipno = @c_Sparm02   
                      AND PD.Cartonno = CAST(@c_Sparm03 as int)    

  
  
   IF @b_debug=1  
   BEGIN  
      SELECT * FROM #Result (nolock)  
   END  
  
   SELECT * FROM #Result (nolock)  
  
EXIT_SP:  
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
  
  
END -- procedure 


GO
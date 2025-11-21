SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                     
/* Copyright: IDS                                                             */                     
/* Purpose: isp_Bartender_OBCTNLBL_001                                        */                     
/*                                                                            */                     
/* Modifications log:                                                         */                     
/*                                                                            */                     
/* Date       Rev  Author     Purposes                                        */     
/* 2023-08-17 1.0  CSCHONG    Devops Scripts Combine & WMS-23367-Create       */                  
/******************************************************************************/   
CREATE   PROC [dbo].[isp_Bartender_OBCTNLBL_001]                 
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
      @c_PalletKey         NVARCHAR(50),              
      @c_SKU               NVARCHAR(20),             
      @c_serialno          NVARCHAR(4000),        
      @c_SQL               NVARCHAR(4000),  
      @c_SQLSORT           NVARCHAR(4000),  
      @c_SQLJOIN           NVARCHAR(4000),  
      @n_TTLCopy           INT,  
      @c_ChkStatus         NVARCHAR(2),  
      @c_Uccno             NVARCHAR(80),  
      @c_storerkey         NVARCHAR(80),  
      @n_continue          INT,  
      @c_ExecStatements    NVARCHAR(4000),     
      @c_ExecArguments     NVARCHAR(4000),  
      @n_MaxLine           INT,     
      @n_pageno            INT,     
      @n_totalpg           INT,
      @c_SBUSR1            NVARCHAR(30),
      @n_STDGrossWGT       FLOAT = 0 ,
      @n_TTLWGT            FLOAT = 0 ,
      @n_TTLQTY            INT   = 0  
             
   
  
    -- SET RowNo = 0       
    SET @c_SQL = ''    
    SET @n_TTLCopy = 1  
    SET @n_MaxLine = 100  
        
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
  
  
    SELECT TOP 1 @c_sku = PD.sku
                 ,@c_storerkey = PH.StorerKey
    FROM PACKHEADER PH WITH (NOLOCK) 
	 JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
	 WHERE PH.Pickslipno = @c_Sparm01
	 AND PD.LabelNo = @c_Sparm02

    SELECT @c_SBUSR1 = ISNULL(S.BUSR1,''),
           @n_STDGrossWGT = S.STDGROSSWGT
    FROM SKU S WITH (NOLOCK)
    WHERE S.StorerKey = @c_storerkey
    AND S.sku = @c_SKU

    SELECT @n_TTLQTY = SUM(PD.qty)
    FROM PACKHEADER PH WITH (NOLOCK) 
	 JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
	 WHERE PH.Pickslipno = @c_Sparm01
	 AND PD.LabelNo = @c_Sparm02


    SET @n_TTLWGT = @n_TTLQTY * @n_STDGrossWGT
         
         
     INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09    
             ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22    
             ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34    
             ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44   
             ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54  
             ,Col55,Col56,Col57,Col58,Col59,Col60)  

    SELECT DISTINCT ST.Company,O.StorerKey,O.ExternOrderKey,o.OrderKey,ISNULL(o.Stop,''),     --5
          ISNULL(o.Route,''),ISNULL(o.userdefine09,''),CONVERT(NVARCHAR(10),o.DeliveryDate,104),o.ConsigneeKey,ISNULL(o.C_Company,''),  --10
           ISNULL(o.C_contact1,''),ISNULL(o.C_Address1,''),ISNULL(o.C_Address2,''),ISNULL(o.C_Address3,''),ISNULL(o.C_Address4,''),--15
           ISNULL(o.C_City,''),ISNULL(o.C_Zip,''),ISNULL(o.C_Country,''),ISNULL(o.C_State,''),SUBSTRING(ISNULL(o.Notes,''),1,80), --20
           PH.PickSlipNo,pd.LabelNo,pd.CartonNo,@c_Sparm03,@n_TTLWGT,@n_TTLQTY,o.LoadKey,ISNULL(ST.B_Company,''),ISNULL(ST.B_contact1,''),ISNULL(ST.B_Address1,''), --30
           ISNULL(ST.B_Address2,''),ISNULL(ST.B_Address3,''),ISNULL(ST.B_Address4,''),ISNULL(ST.B_City,''),ISNULL(ST.B_Zip,''),  --35
           ISNULL(ST.B_Country,''),ISNULL(ST.B_State,''),@c_SBUSR1,'','',   --40
           '','','','','','','','','','',    --50
           '','','','','','','','','',''     --60
    FROM PACKHEADER PH WITH (NOLOCK) 
	 JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
	 LEFT JOIN ORDERS O WITH (NOLOCK) ON O.Orderkey = pH.orderkey
    JOIN dbo.STORER ST WITH (NOLOCK) ON ST.StorerKey = O.StorerKey
	 WHERE PH.Pickslipno = @c_Sparm01
	 AND PD.LabelNo = @c_Sparm02
    
   SELECT * FROM #Result WITH (NOLOCK)  

  
   EXIT_SP:         
                                 
   END -- procedure       


GO
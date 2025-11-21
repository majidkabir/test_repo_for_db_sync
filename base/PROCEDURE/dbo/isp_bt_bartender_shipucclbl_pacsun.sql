SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                   
/* Copyright: LFL                                                             */                   
/* Purpose: isp_BT_Bartender_SHIPUCCLBL_PacSun                                */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */  
/*01-JUNE-2021 1.0  CHONGCS    Created (WMS-17112)                            */  
/*15-APR-2022 1.1  MINGLE     Change extordkey to udf03 (WMS-19458)(ML01)     */
/*07-JUL-2022 1.2  MINGLE     Add col 15-17 (WMS-20128)(ML02)                 */
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_SHIPUCCLBL_PacSun]                        
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
           
                                
   DECLARE @c_ReceiptKey       NVARCHAR(10),                      
           @c_sku              NVARCHAR(80),                           
           @n_intFlag          INT,       
           @n_CntRec           INT,      
           @c_SQL              NVARCHAR(4000),          
           @c_SQLSORT          NVARCHAR(4000),          
           @c_SQLJOIN          NVARCHAR(4000)
      
   DECLARE @d_Trace_StartTime  DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20),       
           @c_ExecStatements   NVARCHAR(4000),      
           @c_ExecArguments    NVARCHAR(4000),
           @n_Sum              FLOAT,
           @n_MaxCarton        INT = 0,
           @c_Storerkey        NVARCHAR(15),
           @c_OrderKey         NVARCHAR(10),
           @c_OrdType          NVARCHAR(10),   
           @c_descr            NVARCHAR(80),
           @c_style            NVARCHAR(40),
           @c_color            NVARCHAR(20),
           @c_size             NVARCHAR(20),  
           @c_labelno          NVARCHAR(20),
           @c_Col13            NVARCHAR(80),
           @c_TableLinkage     NVARCHAR(4000)
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0               
   SET @c_SQL = ''       
   SET @c_sku = ''
   SET @c_descr = ''
   SET @c_style = ''
   SET @c_color = ''
   SET @c_size = ''
   SET @c_OrdType = ''
   SET @c_Col13  = ''
                
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
     
   SELECT @c_Storerkey = PH.Storerkey
        , @c_OrderKey  = PH.Orderkey
   FROM Packheader PH (NOLOCK)
   WHERE PH.Pickslipno = @c_Sparm01      

   IF ISNULL(@c_OrderKey,'') = ''
   BEGIN
     GOTO EXIT_SP
   END
   ELSE
   BEGIN
      
        SELECT @c_OrdType = ORD.Type
        FROM ORDERS ORD WITH (NOLOCK)
        WHERE ORD.OrderKey = @c_OrderKey

   END

     SELECT TOP 1 @c_sku = PD.SKU 
                 ,@c_descr = ISNULL(RTRIM(S.DESCR),'')
                 ,@c_style = ISNULL(S.Style,'')
                 ,@c_color = ISNULL(S.Color,'')
                 ,@c_size = ISNULL(S.Size,'')
                 ,@c_labelno = PD.LabelNo
     FROM dbo.PackHeader PH WITH (NOLOCK)
     JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
     JOIN SKU S WITH (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.sku = PD.SKU
     WHERE PH.PickSlipNo = @c_Sparm01  
     AND  PD.Cartonno >= CONVERT(INT,@c_Sparm02)
     AND PD.Cartonno <= CONVERT(INT,@c_Sparm03)


    IF @c_OrdType <>'casepack'
    BEGIN
        SET @c_sku = ''
        SET @c_descr = ''
        SET @c_style = ''
        SET @c_color = ''
        SET @c_size = ''
        SET @c_Col13 = ''
    END
    ELSE
    BEGIN
         SET @c_Col13 = 'style ' +SPACE(2) + @c_style +SPACE(2)+ 'color ' +@c_color +SPACE(2) + 'size '+SPACE(2)+ @c_size
    END 
         
   SET @c_SQLJOIN = N' SELECT DISTINCT ISNULL(F.Descr,''''), ISNULL(F.Address1,'''') + ISNULL(F.Address2,''''),  '
                  +  ' ISNULL(F.Address3,'''') + ISNULL(F.Address4,''''), '
                  +  ' ISNULL(F.City,'''') + '','' + ISNULL(F.State,'''') + '','' + ISNULL(F.Country,''''),ST.Company, ' + CHAR(13) --5
                  +  ' ISNULL(ST.Address1,'''') + ISNULL(ST.Address2,''''), ISNULL(ST.City,'''') + '','' + ISNULL(ST.State,''''),'  --7
                  +  ' OH.Consigneekey, ST.Zip, OH.Userdefine03, ' + CHAR(13) --10	--ML01
                  +  ' @c_descr, @c_sku, @c_Col13, @c_labelno, oh.bizunit, oh.userdefine02, oh.userdefine04, '''', '''', '''', ' + CHAR(13) --20	--ML02
                  +  ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --30
                  +  ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --40
                  +  ' '''', '''', '''', '''', '''', '''', '''', '''', '''', '''', ' + CHAR(13) --50
                  +  ' '''', '''', '''', '''', '''', '''', '''', '''', PH.Pickslipno, ''CN'' ' + CHAR(13) --60
                  +  ' FROM PACKHEADER PH (NOLOCK)  ' + CHAR(13)
                  +  ' JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = PH.Orderkey ' + CHAR(13)
                  +  ' JOIN FACILITY F WITH (NOLOCK) ON F.Facility = OH.Facility ' 
                  +  ' LEFT JOIN STORER ST (NOLOCK) ON ST.Storerkey = OH.Consigneekey ' + CHAR(13)   
                  +  ' WHERE PH.Pickslipno = @c_Sparm01 '           + CHAR(13)
                  --+  ' AND PD.Cartonno >= CONVERT(INT,@c_Sparm02) ' + CHAR(13)                             
                  --+  ' AND PD.Cartonno <= CONVERT(INT,@c_Sparm03) ' + CHAR(13) 
                  --+  ' GROUP BY ISNULL(ST.SUSR2,''''), ISNULL(ST.B_City,''''), ISNULL(ST.Address3,''''), PD.LabelNo, PH.Pickslipno '
         
   IF @b_debug=1          
   BEGIN
      PRINT @c_SQLJOIN            
   END                  
                
   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +             
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +             
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +             
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +             
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +             
             +',Col55,Col56,Col57,Col58,Col59,Col60) '            
      
   SET @c_SQL = @c_SQL + @c_SQLJOIN      
  
  
   SET @c_ExecArguments = N'   @c_Sparm01          NVARCHAR(80) '      
                         + ',  @c_descr            NVARCHAR(80) '      
                         + ',  @c_sku              NVARCHAR(80) ' 
                         + ',  @c_Col13            NVARCHAR(80) ' 
                         + ',  @c_labelno          NVARCHAR(80) ' 
                       --  + ',  @c_Sparm06          NVARCHAR(80) ' 
                                              
   EXEC sp_ExecuteSql     @c_SQL       
                        , @c_ExecArguments      
                        , @c_Sparm01     
                        , @c_descr 
                        , @c_sku
                        , @c_Col13
                        , @c_labelno


   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL           
   END        
            
   SELECT * FROM #Result (nolock)      

EXIT_SP:                
                                   
END -- procedure     

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_Bartender_Shipper_Label_KR                                    */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2015-10-06 1.0  CSCHONG    Created (SOS352067)                             */    
/* 2016-01-06 1.1  CSCHONG    Change mapping (CS01)                           */   
/* 2016-03-16 1.2  CSCHONG    Add new field (CS02)                            */        
/* 2018-04-20 1.3  CSCHONG    REmove SET ANSI_WARNINGS with dynamic sql(CS03) */          
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_Bartender_Shipper_Label_KR]                        
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
   @b_debug             INT = 0                           
)                        
AS                        
BEGIN                        
   SET NOCOUNT ON                   
   SET ANSI_NULLS OFF                  
   SET QUOTED_IDENTIFIER OFF                   
   SET CONCAT_NULL_YIELDS_NULL OFF                  
  -- SET ANSI_WARNINGS OFF                       --(CS03)  
                                
   DECLARE                    
      @c_ReceiptKey      NVARCHAR(10),                      
      @c_ExternOrderKey  NVARCHAR(10),                
      @c_Deliverydate    DATETIME,                
      @n_intFlag         INT,       
      @n_CntRec          INT,      
      @c_SQL             NVARCHAR(4000),   
      @c_SQLParm         NVARCHAR(4000),      --(CS03)         
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_GetSKU01        NVARCHAR(80),  
      @c_GetSKUDESCR01   NVARCHAR(80),  
      @c_GetQty01        NVARCHAR(10),  
      @c_GetSKU02        NVARCHAR(80),  
      @c_GetSKUDESCR02   NVARCHAR(80),  
      @c_GetQty02        NVARCHAR(10),  
      @c_GetSKU03        NVARCHAR(80),  
      @c_GetSKUDESCR03   NVARCHAR(80),  
      @c_GetQty03        NVARCHAR(10),  
      @c_GetPickslipno   NVARCHAR(80),  
      @c_GetCartonNo     NVARCHAR(10),  
      @c_TTLCNT          NVARCHAR(10),  
      @c_labelline       NVARCHAR(5),  
      @c_Pickslipno      NVARCHAR(80),  
      @c_CartonNo        NVARCHAR(10)  
        
      
  DECLARE @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20)       
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0               
    SET @c_SQL = ''   
    SET @c_GetPickslipno   = ''  
    SET @c_GetCartonNo     = ''     
                
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
                
        IF @b_debug=1          
         BEGIN          
            PRINT 'start'            
         END          
  SET @c_SQLJOIN = +' SELECT DISTINCT ORD.c_Company,ORD.c_phone1,(ORD.C_City + '' '' + ORD.C_Address3 + '' '' + ORD.c_Address2) AS Add1,'+ CHAR(13) +     --3       
             + ' ORD.C_Zip,(STO.Company + '' '' + STO.City +Ã¡ '' ''   + STO.Address3 +  '' ''   + STO.Address2) As Add2,'      --5  
             + ' SUBSTRING(ORD.C_Company,1,LEN(ORD.C_Company) - LEN(RIGHT(ORD.C_Company, 1))) + ''*'','             --CS01  
             + ' SUBSTRING(ORD.C_Phone1,1,LEN(ORD.C_Phone1) - LEN(RIGHT(ORD.C_Phone1, 4))) + ''****'','             --CS01  
             --+ '(ORD.C_City + '' '' + ORD.C_Address3 + '' '' + ORD.c_Address2) AS Add3,'     --8  
             +'Substring(PACKDET.Labelno,1,4) + ''-'' + Substring(PACKDET.Labelno,5,4)  +''-'' +  Substring(PACKDET.Labelno,9,4), '  
             + ' PACKDET.Labelno,ORD.B_Country,ORD.B_State AS bState,'''','''','''','''', '                       --15     
             + CHAR(13) +        
             + ' '''','''','''','''','''','         --20        
             + ' ORD.B_Company,ORD.B_City,ORD.B_Contact1,PACKDET.Cartonno,ORD.ExternOrderKey,ORD.B_Contact2,ORD.B_Address1,ORD.B_Address2,ORD.B_Address3,ORD.B_Address4,'  --30    
             + ' '''','''','''','''','''','''','''','''','''','''','   --40         
             + ' '''','''','''','''','''','''','''','''','''','''', '  --50         
             + ' '''','''','''','''','''','''','''','''',PACKH.OrderKey, PACKDET.Pickslipno '   --60            
             + CHAR(13) +              
             + ' FROM ORDERS ORD WITH (NOLOCK)'         
             + ' JOIN PACKHEADER PACKH WITH (NOLOCK) ON PACKH.OrderKey= ORD.OrderKey'    
             + ' JOIN PACKDETAIL PACKDET WITH (NOLOCK) ON PACKH.Pickslipno = PACKDET.Pickslipno'   
             + ' LEFT JOIN CARTONTRACK CT WITH (NOLOCK) ON CT.labelno = PACKDET.labelno'   
             + ' JOIN STORER STO WITH (NOLOCK) ON ORD.Storerkey=STO.Storerkey'  
             + ' WHERE PACKH.OrderKey = @c_Sparm01 '     
             + ' AND PACKDET.Cartonno = CASE WHEN ISNULL(RTRIM(@c_Sparm02),'''')<> '''' THEN  @c_Sparm02 ELSE PACKDET.Cartonno END'    
                         
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
  
      
          
   --EXEC sp_executesql @c_SQL      --CS03 start  
     
   SET @c_SQLParm =  N'@c_Sparm01 NVARCHAR(250), @c_Sparm02 NVARCHAR(250), @c_Sparm03 NVARCHAR(250), @c_Sparm04  NVARCHAR(250), ' +  
                     ' @c_Sparm05 NVARCHAR(250), @c_Sparm06 NVARCHAR(250), @c_Sparm07 NVARCHAR(250),  @c_Sparm08 NVARCHAR(250), ' +  
                     ' @c_Sparm09 NVARCHAR(250), @c_Sparm10  NVARCHAR(250) '  
                                  
          
   EXEC sp_executesql @c_SQL, @c_SQLParm, @c_Sparm01, @c_Sparm02 , @c_Sparm03, @c_Sparm04, @c_Sparm05, @c_Sparm06, @c_Sparm07,  
                     @c_Sparm08, @c_Sparm09, @c_Sparm10        
   --CS03 End       
   IF @b_debug=1          
   BEGIN            
       PRINT @c_SQL            
   END    
  
  SET @c_GetSKU01        = ''  
  SET @c_GetSKUDESCR01   = ''  
  SET @c_GetQty01        = ''  
  SET @c_GetSKU02        = ''  
  SET @c_GetSKUDESCR02   = ''  
  SET @c_GetQty02        = ''  
  SET @c_GetSKU03        = ''  
  SET @c_GetSKUDESCR03   = ''  
  SET @c_GetQty03        = ''  
  SET @c_Pickslipno     = ''  
  SET @c_CartonNo       = ''   
  
    SET @c_TTLCNT = 0  
  
    SELECT @c_TTLCNT = MAX(CartonNo)  
    FROM PACKDETAIL WITH (NOLOCK)  
    WHERE Pickslipno = @c_Sparm01  
  
     
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT Col60,col24     
   FROM   #Result     
   WHERE  Col59=@c_Sparm01   
  
   OPEN CUR_RESULT     
   FETCH NEXT FROM CUR_RESULT INTO @c_Pickslipno,@c_CartonNo      
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN  
  
    DECLARE CUR_LOOPRESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT Pickslipno,cartonno,LabelLine     
      FROM   PACKDETAIL WITH (NOLOCK)     
      WHERE  Pickslipno=@c_Pickslipno  
      AND CartonNo =  @c_CartonNo  
  
      OPEN CUR_LOOPRESULT     
      FETCH NEXT FROM CUR_LOOPRESULT INTO @c_GetPickslipno,@c_GetCartonNo,@c_LabelLine      
       
      WHILE @@FETCH_STATUS <> -1    
      BEGIN  
  
    IF @b_debug='1'  
    BEGIN  
  
     SELECT 'labelLine', @c_LabelLine , 'pickslipno',@c_GetPickslipno,'cartonno',@c_GetCartonNo  
    END  
  
   IF @c_LabelLine = '00001'  
   BEGIN  
     SELECT @c_GetSKU01 = PACKDET.SKU,  
            @c_GetSKUDESCR01 = S.descr,  
            @c_GetQty01 = CONVERT(NVARCHAR(10),PACKDET.qty)  
     FROM PACKDETAIL PACKDET WITH (NOLOCK)  
     JOIN SKU S WITH (NOLOCK) ON S.Sku = PACKDET.SKU  
     WHERE PACKDET.Pickslipno = @c_GetPickslipno  
     AND PACKDET.CartonNo = @c_GetCartonNo  
     AND PACKDET.LabelLine = @c_LabelLine  
   END  
   ELSE IF @c_LabelLine = '00002'  
   BEGIN  
     SELECT @c_GetSKU02 = PACKDET.SKU,  
            @c_GetSKUDESCR02 = S.descr,  
            @c_GetQty02 = CONVERT(NVARCHAR(10),PACKDET.qty)  
   FROM PACKDETAIL PACKDET WITH (NOLOCK)  
     JOIN SKU S WITH (NOLOCK) ON S.Sku = PACKDET.SKU  
     WHERE PACKDET.Pickslipno = @c_GetPickslipno  
     AND PACKDET.CartonNo = @c_GetCartonNo  
     AND PACKDET.LabelLine = @c_LabelLine  
   END  
   ELSE IF @c_LabelLine = '00003'  
   BEGIN  
    SELECT  @c_GetSKU03 = PACKDET.SKU,  
            @c_GetSKUDESCR03 = S.descr,  
            @c_GetQty03 = CONVERT(NVARCHAR(10),PACKDET.qty)  
     FROM PACKDETAIL PACKDET WITH (NOLOCK)  
     JOIN SKU S WITH (NOLOCK) ON S.Sku = PACKDET.SKU  
     WHERE PACKDET.Pickslipno = @c_GetPickslipno  
     AND PACKDET.CartonNo = @c_GetCartonNo  
     AND PACKDET.LabelLine = @c_LabelLine  
    END  
  
       FETCH NEXT FROM CUR_LOOPRESULT INTO @c_GetPickslipno,@c_GetCartonNo,@c_LabelLine     
       END  
  
       CLOSE CUR_LOOPRESULT  
       DEALLOCATE  CUR_LOOPRESULT  
      
   UPDATE #Result  
   SET  col12 =  @c_GetSKU01,  
        col13 =  @c_GetSKUDESCR01,  
        col14 =  @c_GetQty01,  
        col15 =  @c_GetSKU02,  
        col16 =  @c_GetSKUDESCR02,  
        col17 =  @c_GetQty02,  
        col18 =  @c_GetSKU03,  
        col19 =  @c_GetSKUDESCR03,     
        col20 =  @c_GetQty03,  
        col25 =  @c_TTLCNT    
   WHERE Col60 = @c_Pickslipno  
   AND   Col24 = @c_CartonNo  
  
    FETCH NEXT FROM CUR_RESULT INTO @c_Pickslipno,@c_CartonNo     
    END  
  
      CLOSE CUR_RESULT  
      DEALLOCATE  CUR_RESULT  
  
      
       
   IF @b_debug=1          
   BEGIN          
      SELECT * FROM #Result (nolock)          
   END          
        
   SELECT * FROM #Result (nolock)          
              
   EXIT_SP:      
    
      SET @d_Trace_EndTime = GETDATE()    
      SET @c_UserName = SUSER_SNAME()    
       
      EXEC isp_InsertTraceInfo     
         @c_TraceCode = 'BARTENDER',    
         @c_TraceName = 'isp_Bartender_Shipper_Label_KR',    
         @c_starttime = @d_Trace_StartTime,    
         @c_endtime = @d_Trace_EndTime,    
         @c_step1 = @c_UserName,    
         @c_step2 = '',    
         @c_step3 = '',    
         @c_step4 = '',    
         @c_step5 = '',    
         @c_col1 = @c_Sparm01,     
         @c_col2 = @c_Sparm02,    
         @c_col3 = @c_Sparm03,    
         @c_col4 = @c_Sparm04,    
         @c_col5 = @c_Sparm05,    
         @b_Success = 1,    
         @n_Err = 0,    
         @c_ErrMsg = ''                
     
    
                                    
   END -- procedure     
  

GO
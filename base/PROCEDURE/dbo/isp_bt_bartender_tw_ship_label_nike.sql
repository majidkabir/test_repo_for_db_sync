SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_BT_Bartender_TW_Ship_Label_NIKE                               */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2017-06-29 1.0  CSCHONG    Created (WMS-1953)                              */   
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_BT_Bartender_TW_Ship_Label_NIKE]                        
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
   --SET ANSI_WARNINGS OFF                   --CS03                     
                                
   DECLARE                                      
      @c_GetSku          NVARCHAR(20),                            
      @c_SQL             NVARCHAR(4000),          
      @c_SQLSORT         NVARCHAR(4000),          
      @c_SQLJOIN         NVARCHAR(4000),  
      @n_Qty             INT,  
      @c_pickslipno      NVARCHAR(80),  
      @c_col08           NVARCHAR(80),  
      @c_cartonno        NVARCHAR(80),  
      @c_getPickslip     NVARCHAR(80),  
      @c_getCartonno     NVARCHAR(80),  
      @n_getqty          INT,    
      @n_rowid           INT,  
      @n_CntRec          INT,  
      @c_col13           NVARCHAR(80),    
      @c_col14           NVARCHAR(80),  
      @c_col15           NVARCHAR(80),  
      @c_col16           NVARCHAR(80),  
      @c_col17           NVARCHAR(80),  
      @c_col18           NVARCHAR(80),  
      @c_col19           NVARCHAR(80),  
      @c_col20           NVARCHAR(80),  
      @c_col21           NVARCHAR(80),  
      @c_col22           NVARCHAR(80),  
      @c_col23           NVARCHAR(80),  
      @n_maxline         INT,  
      @n_RecGrp          INT,  
      @n_lineno          INT,  
      @n_PreRecGrp       INT  
             
            
      
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
    SET @c_getSku = ''    
    SET @n_Qty = 0    
    SET @c_col08 = 'SKU                 ' + SPACE(1) + 'Qty '   + CHAR(13)  
    SET @c_col13  = ''  
    SET @c_col14  = ''  
    SET @c_col15  = ''  
    SET @c_col16  = ''  
    SET @c_col17  = ''  
    SET @c_col18 = ''  
    SET @c_col19 = ''  
    SET @c_col20  = ''  
    SET @c_col21  = ''  
    SET @c_col22  = ''  
    SET @c_col23  = ''  
    SET @n_maxline = 2  
    SET @n_PreRecGrp = 0  
    SET @n_lineno = 1  
                
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
       
     CREATE TABLE #PSKU (  
       [ID]    [INT] IDENTITY(1,1) NOT NULL,    
       Pickslipno    NVARCHAR(20) NULL,  
       Cartonno      NVARCHAR(20) NULL,  
       SKU           NVARCHAR(20) NULL,  
       Qty           INT,  
       RecGrp        INT   
          
     )  
                
                
              
  SET @c_SQLJOIN = +N' SELECT DISTINCT ISNULL(SSOD.Route,''''),o.C_Company,ISNULL(o.C_Address2,''''),'  
       + ' ISNULL(o.C_city,''''),o.ExternOrderkey,'           --5  
       + ' CONVERT(nvarchar(5),pd.CartonNo),'  
       + N' CASE WHEN o.status=N''5'' THEN N''共'' +space(2)+ CONVERT(nvarchar(5),ph.ttlcnts) +space(2) +N''件'' ELSE '''' END ,'       --7  
       + ' '''',pd.pickslipno,CONVERT(CHAR(10),lp.lpuserdefdate01,111),' --10                 --(CS02)  
       + 'o.userdefine05,S.CustomerGroupCode,'''','''','''', ' --15    
       + ' '''','''','''','''','''','     --20         
     --    + CHAR(13) +        
       + ' '''','''','''',pd.labelno,'''','''','''','''','''','''','  --30    
       + ' '''','''','''','''','''','''','''','''','''','''','   --40         
       + ' '''','''','''','''','''','''','''','''','''','''', '  --50         
       + ' '''','''','''','''','''','''','''','''','''','''' '   --60            
       --  + CHAR(13) +              
       + ' FROM PackHeader AS ph WITH (NOLOCK)'         
       + ' JOIN packdetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo'     
       + ' JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey '     
       + ' JOIN STORER S WITH (NOLOCK) ON S.storerkey = o.Storerkey'   
       + ' LEFT JOIN Loadplan LP WITH (NOLOCK) ON LP.loadkey = o.loadkey'  
       + ' LEFT JOIN StorerSODefault SSOD WITH (NOLOCK) ON SSOD.storerkey=o.consigneekey '     
       + ' WHERE pd.pickslipno =''' + @c_Sparm01+ ''' '       
      -- + ' AND PD.CartonNo = CONVERT(INT,''' + @c_Sparm02+ ''' )'     
       + ' AND pd.labelno = '''+ @c_Sparm02+ ''' '   
        
            
IF @b_debug=1          
BEGIN          
   SELECT @c_SQLJOIN            
END                  
                
  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +             
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +             
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +             
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +             
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +             
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '            
      
SET @c_SQL = @c_SQL + @c_SQLJOIN          
          
EXEC sp_executesql @c_SQL            
          
   IF @b_debug=1          
   BEGIN            
      PRINT @c_SQL            
   END          
   IF @b_debug=1          
   BEGIN          
      SELECT * FROM #Result (nolock)          
   END          
  
   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                           
   SELECT DISTINCT Col09,Col06  
   FROM #Result            
         
   OPEN CUR_RowNoLoop              
         
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_pickslipno,@c_cartonno      
           
   WHILE @@FETCH_STATUS <> -1              
   BEGIN     
      
    INSERT INTO #PSKU  
    (  
     Pickslipno,  
     Cartonno,  
     SKU,  
     Qty,  
     Recgrp  
    )  
    SELECT pd.PickSlipNo,pd.CartonNo,pd.SKU,SUM(pd.Qty)  
    ,(Row_Number() OVER (PARTITION BY pd.PickSlipNo ORDER BY pd.SKU Asc)-1)/@n_maxline+1 AS RECGRP  
    FROM PACKDETAIL PD WITH (NOLOCK)  
    WHERE pd.PickSlipNo=@c_pickslipno  
    AND pd.CartonNo = CONVERT (INT,@c_cartonno)  
    GROUP BY pd.PickSlipNo,pd.CartonNo,pd.SKU  
  
       IF @b_debug='1'  
       BEGIN  
        SELECT * FROM #PSKU  
        --GOTO EXIT_SP   
       END  
  
     SET @n_CntRec = 1  
       
   DECLARE CUR_skuLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                           
   SELECT DISTINCT id,pickslipno,Cartonno,sku,qty,RecGrp   
   FROM #PSKU    
   WHERE Pickslipno= @c_pickslipno  
   AND Cartonno = CONVERT(INT, @c_cartonno)      
         
   OPEN CUR_skuLoop              
         
   FETCH NEXT FROM CUR_skuLoop INTO @n_rowid,@c_getPickslip,@c_getcartonno,@c_getsku,@n_Qty ,@n_RecGrp     
           
   WHILE @@FETCH_STATUS <> -1              
   BEGIN    
      
   --SELECT @n_CntRec = COUNT(1)  
   --FROM #PSKU  
   --WHERE Pickslipno= @c_pickslipno  
   --AND Cartonno = CONVERT(INT, @c_cartonno)   
     
   --IF @n_rowid <> @n_CntRec  
      IF @n_CntRec = 1 AND @n_RecGrp=@n_RecGrp  
      BEGIN   
      IF @n_lineno <> @n_maxline  
      BEGIN   
        SET @c_col08 = @c_col08 + left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5) + CHAR(13)  
        SET @n_lineno = @n_lineno + 1  
      END  
      ELSE  
      BEGIN  
       SET @c_col08 = @c_col08 + left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5)  
       SET @n_CntRec = @n_CntRec + 1  
       SET @n_lineno = 1  
      END    
      END  
      ELSE IF @n_CntRec = 2 AND @n_RecGrp=@n_RecGrp  
      BEGIN   
      IF @n_lineno <> @n_maxline  
      BEGIN   
        SET @c_col13 =left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5) + CHAR(13)  
        SET @n_lineno = @n_lineno + 1  
      END  
      ELSE  
      BEGIN  
       SET @c_col13 = @c_col13 + left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5)  
       SET @n_CntRec = @n_CntRec + 1  
       SET @n_lineno = 1  
      END    
      END   
      ELSE IF @n_CntRec = 3 AND @n_RecGrp=@n_RecGrp  
      BEGIN   
      IF @n_lineno <> @n_maxline  
      BEGIN   
        SET @c_col14 =left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5) + CHAR(13)  
        SET @n_lineno = @n_lineno + 1  
      END  
      ELSE  
      BEGIN  
       SET @c_col14 = @c_col14 + left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5)  
       SET @n_CntRec = @n_CntRec + 1  
       SET @n_lineno = 1  
      END    
      END  
      ELSE IF @n_CntRec = 4 AND @n_RecGrp=@n_RecGrp  
      BEGIN   
      IF @n_lineno <> @n_maxline  
      BEGIN   
        SET @c_col15 =left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5) + CHAR(13)  
        SET @n_lineno = @n_lineno + 1  
      END  
      ELSE  
      BEGIN  
       SET @c_col15 = @c_col15 + left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5)  
       SET @n_CntRec = @n_CntRec + 1  
       SET @n_lineno = 1  
      END    
      END  
      ELSE IF @n_CntRec = 5 AND @n_RecGrp=@n_RecGrp  
      BEGIN   
      IF @n_lineno <> @n_maxline  
      BEGIN   
        SET @c_col16 =left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5) + CHAR(13)  
        SET @n_lineno = @n_lineno + 1  
      END  
      ELSE  
      BEGIN  
       SET @c_col16 = @c_col16 + left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5)  
       SET @n_CntRec = @n_CntRec + 1  
       SET @n_lineno = 1  
      END    
      END  
      ELSE IF @n_CntRec = 6 AND @n_RecGrp=@n_RecGrp  
      BEGIN   
      IF @n_lineno <> @n_maxline  
      BEGIN   
        SET @c_col17 =left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5) + CHAR(13)  
        SET @n_lineno = @n_lineno + 1  
      END  
      ELSE  
      BEGIN  
       SET @c_col17 = @c_col17 + left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5)  
       SET @n_CntRec = @n_CntRec + 1  
       SET @n_lineno = 1  
      END    
      END  
      ELSE IF @n_CntRec = 7 AND @n_RecGrp=@n_RecGrp  
      BEGIN   
      IF @n_lineno <> @n_maxline  
      BEGIN   
        SET @c_col18 =left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5) + CHAR(13)  
        SET @n_lineno = @n_lineno + 1  
      END  
      ELSE  
      BEGIN  
       SET @c_col18 = @c_col18 + left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5)  
       SET @n_CntRec = @n_CntRec + 1  
       SET @n_lineno = 1  
      END    
      END  
      ELSE IF @n_CntRec = 8 AND @n_RecGrp=@n_RecGrp  
      BEGIN   
      IF @n_lineno <> @n_maxline  
      BEGIN   
        SET @c_col19 =left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5) + CHAR(13)  
        SET @n_lineno = @n_lineno + 1  
      END  
      ELSE  
      BEGIN  
       SET @c_col19 = @c_col19 + left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5)  
       SET @n_CntRec = @n_CntRec + 1  
       SET @n_lineno = 1  
      END    
      END  
      ELSE IF @n_CntRec = 9 AND @n_RecGrp=@n_RecGrp  
      BEGIN   
      IF @n_lineno <> @n_maxline  
      BEGIN   
        SET @c_col20 =left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5) + CHAR(13)  
        SET @n_lineno = @n_lineno + 1  
      END  
      ELSE  
      BEGIN  
       SET @c_col20 = @c_col20 + left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5)  
       SET @n_CntRec = @n_CntRec + 1  
       SET @n_lineno = 1  
      END    
      END  
      ELSE IF @n_CntRec = 10 AND @n_RecGrp=@n_RecGrp  
      BEGIN   
      IF @n_lineno <> @n_maxline  
      BEGIN   
        SET @c_col21 =left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5) + CHAR(13)  
        SET @n_lineno = @n_lineno + 1  
      END  
      ELSE  
      BEGIN  
       SET @c_col21 = @c_col21 + left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5)  
       SET @n_CntRec = @n_CntRec + 1  
       SET @n_lineno = 1  
      END    
      END  
      ELSE IF @n_CntRec = 11 AND @n_RecGrp=@n_RecGrp  
      BEGIN   
      IF @n_lineno <> @n_maxline  
      BEGIN   
        SET @c_col22 =left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5) + CHAR(13)  
        SET @n_lineno = @n_lineno + 1  
      END  
      ELSE  
      BEGIN  
       SET @c_col22 = @c_col22 + left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5)  
       SET @n_CntRec = @n_CntRec + 1  
       SET @n_lineno = 1  
      END    
      END  
      ELSE IF @n_CntRec = 12 AND @n_RecGrp=@n_RecGrp  
      BEGIN   
      IF @n_lineno <> @n_maxline  
      BEGIN   
        SET @c_col23 =left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5) + CHAR(13)  
        SET @n_lineno = @n_lineno + 1  
      END  
      ELSE  
      BEGIN  
       SET @c_col23 = @c_col23 + left(@c_getsku + replicate(' ',20),20) + SPACE(2) + left(CONVERT(NVARCHAR(5),@n_Qty)+ replicate(' ',5),5)  
       SET @n_CntRec = @n_CntRec + 1  
       SET @n_lineno = 1  
      END    
      END  
       
   FETCH NEXT FROM CUR_skuLoop INTO @n_rowid,@c_getPickslip,@c_getcartonno,@c_getsku,@n_Qty  ,@n_RecGrp    
   END -- While               
   CLOSE CUR_skuLoop              
   DEALLOCATE CUR_skuLoop       
      
      
       IF @b_debug='1'  
       BEGIN  
        PRINT 'sku : ' + @c_getsku + ' with total qty : ' + convert (nvarchar(10),@n_Qty)  
        SELECT @c_col08 '@c_col08',@c_col13 '@c_col13',@c_col14 '@c_col14',@c_col15 '@c_col15'  
        --GOTO EXIT_SP  
       END  
  
  UPDATE #Result  
  SET  Col08  = @c_col08,  
  Col13 = @c_col13,  
  Col14 = @c_col14,  
  Col15 = @c_col15,  
  Col16 = @c_col16,  
  Col17 = @c_col17,  
  Col18 = @c_col18,  
  Col19 = @c_col19,  
  Col20 = @c_col20,  
  Col21 = @c_col21,  
  Col22 = @c_col22,  
  col23 = @c_col23  
  WHERE col09 = @c_pickslipno  
  AND col06   = @c_cartonno  
  
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_pickslipno,@c_cartonno       
   END -- While               
   CLOSE CUR_RowNoLoop              
   DEALLOCATE CUR_RowNoLoop                    
         
              
EXIT_SP:      
    
   SET @d_Trace_EndTime = GETDATE()    
   SET @c_UserName = SUSER_SNAME()    
       
   EXEC isp_InsertTraceInfo     
      @c_TraceCode = 'BARTENDER',    
      @c_TraceName = 'isp_BT_Bartender_TW_Ship_Label_NIKE',    
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
     
   SELECT * FROM #Result (nolock)   
                                    
END -- procedure     
  


GO
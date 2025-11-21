SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: BarTender Filter by ShipperKey                                    */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2014-01-06 1.0  CSCHONG    Created                                         */   
/* 2014-05-13 1.1  Chee       Bug Fix (Chee01)                                */    
/* 2014-06-09 1.2  CSCHONG    Fix deadlock (CS01)                             */  
/* 2014-12-02 1.3  CSCHONG    Remove SET ANSI_WARNINGS OFF (CS02)             */  
/* 2017-03-20 1.4  CheeMun    IN00294133 - Substring shipToAddress 80 char,   */  
/*                                           added col23 - 26 mapping         */  
/* 2017-03-21 1.5 CSCHONG     WMS-1404 - Change Field maping (CS03)           */  
/* 2017-08-29 1.6 CSCHONG     Scripts tunning (CS04)                          */  
/* 2018-04-18 1.7 CSCHONG     Fix qcommander execute scripts error (CS05)     */  
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_Shipper_Label_DC]                       
(  @c_Sparm1            NVARCHAR(250),              
   @c_Sparm2            NVARCHAR(250),              
   @c_Sparm3            NVARCHAR(250),              
   @c_Sparm4            NVARCHAR(250),              
   @c_Sparm5            NVARCHAR(250),              
   @c_Sparm6            NVARCHAR(250),              
   @c_Sparm7            NVARCHAR(250),              
   @c_Sparm8            NVARCHAR(250),              
   @c_Sparm9            NVARCHAR(250),              
   @c_Sparm10           NVARCHAR(250),        
   @b_debug             INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                
   --SET ANSI_WARNINGS OFF             --(CS02)              
                              
   DECLARE                  
      @c_OrderKey        NVARCHAR(10),                    
      @c_ExternOrderKey  NVARCHAR(10),              
      @c_Deliverydate    DATETIME,              
      @c_caseid          NVARCHAR(20),   
      @c_ORDUDef10       NVARCHAR(20),  
      @c_ORDUDef03       NVARCHAR(20),  
      @c_ItemClass       NVARCHAR(10),  
      @c_SKUGRP          NVARCHAR(10),  
      @c_Style           NVARCHAR(20),   
      @n_intFlag         INT,     
      @n_CntRec          INT,  
      @n_cntsku          INT,  
      @c_Lott03          NVARCHAR(5),  
      @c_PDSKU           NVARCHAR(20),  
      @C_SDESCR          NVARCHAR(60),  
      @c_Company         NVARCHAR(45),              
      @C_Address1        NVARCHAR(45),              
      @C_Address2        NVARCHAR(45),              
      @C_Address3        NVARCHAR(45),              
      @C_Address4        NVARCHAR(45),              
      @C_BuyerPO         NVARCHAR(20),              
      @C_notes2          NVARCHAR(4000),              
      @c_OrderLineNo     NVARCHAR(5),              
      @c_SKU             NVARCHAR(20),              
      @n_Qty             INT,              
      @c_PackKey         NVARCHAR(10),              
      @c_UOM             NVARCHAR(10),              
      @C_PHeaderKey      NVARCHAR(18),              
      @C_SODestination   NVARCHAR(30),            
      @n_RowNo           INT,            
      @n_SumPickDETQTY   INT,            
      @n_SumUnitPrice    INT,          
 @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),      
      @c_Udef04          NVARCHAR(80),            
      @n_TTLPickQTY      INT,    
      @c_ShipperKey      NVARCHAR(15),  
      @n_CntLot03        INT    
     ,@c_ODUdf03        NVARCHAR(80)  --CS03  
     ,@c_SQLGRPBY       NVARCHAR(4000) --CS05     
  
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),  
           @c_ExecStatements    NVARCHAR(4000),   --(CS04)    
           @c_ExecArguments     NVARCHAR(4000),   --(CS04)       
           @c_condition1        NVARCHAR(150),    --(CS04)  
           @c_condition2        NVARCHAR(150),    --(CS04)  
           @c_condition3        NVARCHAR(150)     --(CS04)  
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''        
    SET @n_SumPickDETQTY = 0            
    SET @n_SumUnitPrice = 0       
    SET @c_condition1 =''        --(CS04)  
    SET @c_condition2 = ''       --(CS04)   
    SET @c_condition3 = ''       --(CS04)      
              
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
      
  
     CREATE TABLE [#CartonContent] (             
      [ID]          [INT] IDENTITY(1,1) NOT NULL,                            
      [DUdef10]     [NVARCHAR] (20) NULL,   
      [DUdef03]     [NVARCHAR] (20) NULL,     
      [itemclass]   [NVARCHAR] (10) NULL,    
      [skugroup]    [NVARCHAR] (10) NULL,     
      [style]       [NVARCHAR] (20) NULL,           
      [TTLPICKQTY]  [INT] NULL)     
  
    CREATE TABLE [#COO] (             
      [ID]          [INT] IDENTITY(1,1) NOT NULL,                            
      [Lottable03]  [NVARCHAR] (80) NULL)     
        
      /*CS04 start*/  
        
   IF ISNULL(RTRIM(@c_Sparm2),'') <> ''  
   BEGIN  
    SET @c_condition1 = ' AND ORD.OrderKey = RTRIM(@c_Sparm2)'  
   END     
     
   IF ISNULL(RTRIM(@c_Sparm4),'') <> ''  
   BEGIN  
    SET @c_condition2 = ' AND ORD.type = RTRIM(@c_Sparm4)'  
   END     
     
   IF ISNULL(RTRIM(@c_Sparm5),'') <> ''  
   BEGIN  
    SET @c_condition3 = ' AND PDET.Dropid = RTRIM(@c_Sparm5)'  
   END     
        
   /*CS04 End*/      
     
   /*CS05 Start*/  
     
   SET @c_SQLGRPBY = ' group by sto.company ,(sto.address1+sto.address2+sto.address3+sto.address4),sto.state,sto.city,sto.zip ,sto.country,'   
                   + ' ord.c_company,(ord.c_address1+ord.c_address2+ord.c_address3+ord.c_address4),ord.c_state,ord.c_city ,ord.c_zip ,ord.c_country,ORD.salesman,right (pd.caseid,4),pd.caseid, '         
             + ' ORD.c_address1, ORD.c_address2, ORD.c_address3, ORD.c_address4 '  --(IN00294133)  
     
   /*CS05 END*/         
            
  SET @c_SQLJOIN = +' SELECT DISTINCT sto.company as ShipFrom_Company,(sto.address1+sto.address2+sto.address3+sto.address4) as shipFrom_Address,sto.state as ShipFrom_State,sto.city as ShipFrom_City,sto.zip as ShipFrom_Zip ,'    --5        
             + CHAR(13) +           
             +'sto.country as ShipFrom_Country,ORD.c_company as ShipTo_Company,SUBSTRING((ORD.c_address1+ORD.c_address2+ORD.c_address3+ORD.c_address4),1,80) as shipTo_address,ORD.c_state as ShipTo_State,ORD.c_city as ShipTo_City,'  --5  (IN00294133)    
             + CHAR(13) +          
             +'ORD.c_zip as ShipTo_Zip,ORD.c_country as ShipTo_Country,ORD.Salesman,'''',right(pd.caseid,4),'+ CHAR(13) +     --5     
             +''''','''','''','''',max(od.userdefine01), '  
             + ' max(s.Measurement),pd.caseid,RTRIM(ORD.c_address1),RTRIM(ORD.c_address2),RTRIM(ORD.c_address3),'    --25     (IN00294133)       
             +' RTRIM(ORD.c_address4),'''','''','''','''','     --30        
             + CHAR(13) +          
             +' '''','''','''','''','''','''','''','''','''','''','   --40       
             +' '''','''','''','''','''','''','''','''','''','''', '  --50       
             +' '''','''','''','''','''','''','''','''','''','''' '   --60          
             + CHAR(13) +            
             + ' FROM ORDERS ORD WITH (NOLOCK) INNER JOIN ORDERDETAIL od WITH (NOLOCK) ON od.orderkey=ORD.orderkey'     --(CS01)  
             + ' LEFT OUTER JOIN STORER sto WITH (NOLOCK) ON sto.storerkey = ORD.facility'        
             + ' INNER JOIN SKU s WITH (NOLOCK) ON s.sku=od.sku'   
             + ' and s.storerkey = od.storerkey ' -- (Chee01)   
             + ' JOIN pickdetail pd WITH (NOLOCK) ON pd.orderkey=ORD.orderkey'  
             + ' INNER JOIN PACKHEADER PH WITH (NOLOCK) ON PH.loadkey = ORD.loadkey'  
             + ' INNER JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno' --AND od.sku=od.sku' (Chee01)  
             + ' WHERE ORD.LoadKey = @c_Sparm1 '   
           --  + ' AND ORD.OrderKey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm2+ '''),'''') <> '''' THEN ''' + @c_Sparm2+ ''' ELSE ORD.OrderKey END'    
             + ' AND pd.caseid = @c_Sparm3  '  
           --  + ' AND ORD.type = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm4+ '''),'''') <> '''' THEN ''' + @c_Sparm4+ ''' ELSE ORD.type END'       
           --  + ' AND PDET.Dropid = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm5+ '''),'''') <> '''' THEN ''' + @c_Sparm5+ ''' ELSE PDET.Dropid END'         
       --      + ' group by sto.company ,(sto.address1+sto.address2+sto.address3+sto.address4),sto.state,sto.city,sto.zip ,sto.country,'   
       --      + ' ord.c_company,(ord.c_address1+ord.c_address2+ord.c_address3+ord.c_address4),ord.c_state,ord.c_city ,ord.c_zip ,ord.c_country,ORD.salesman,right (pd.caseid,4),pd.caseid, '         
       --+ ' ORD.c_address1, ORD.c_address2, ORD.c_address3, ORD.c_address4 '  --(IN00294133)  
          
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
    
 SET @c_SQL = @c_SQL + @c_SQLJOIN +  CHAR(13) + @c_condition1  + CHAR(13) + @c_condition2 + CHAR(13) + @c_condition3 + CHAR(13) + @c_SQLGRPBY   --(CS05)  
 /*CS04 start*/    
 SET @c_ExecArguments = N'   @c_Sparm1           NVARCHAR(80)'      
                          + ', @c_Sparm2           NVARCHAR(80) '      
                          + ', @c_Sparm3           NVARCHAR(80)'    
                          + ', @c_Sparm4           NVARCHAR(80) '      
                          + ', @c_Sparm5           NVARCHAR(80)'      
                           
                           
   EXEC sp_ExecuteSql     @c_SQL       
                        , @c_ExecArguments      
                        , @c_Sparm1      
                        , @c_Sparm2      
                        , @c_Sparm3   
                        , @c_Sparm4    
                        , @c_Sparm5  
   
   
       
 --EXEC sp_executesql @c_SQL   
 /*CS04 End*/         
     
     
        
 IF @b_debug=1        
 BEGIN          
  PRINT @c_SQL          
 END    
       
 IF @b_debug=1        
   BEGIN        
    SELECT * FROM #Result (nolock)        
 END        
  
            
DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
          
SELECT DISTINCT col22 from #Result          
    
OPEN CUR_RowNoLoop            
    
FETCH NEXT FROM CUR_RowNoLoop INTO @c_caseid       
      
WHILE @@FETCH_STATUS <> -1            
BEGIN           
   IF @b_debug='1'        
   BEGIN        
      PRINT @c_caseid           
   END     
  
   INSERT INTO #COO (Lottable03)  
   SELECT  DISTINCT L.lottable03  
   FROM ORDERDETAIL OD WITH (NOLOCK)   
   INNER JOIN PickDetail PD WITH (NOLOCK) ON PD.orderkey=OD.Orderkey AND PD.Storerkey=OD.Storerkey AND PD.SKU=OD.SKU  
   INNER JOIN lotattribute L WITH (NOLOCK) ON L.Lot=PD.Lot AND L.Storerkey=PD.Storerkey AND L.SKU=PD.SKU  
   INNER JOIN SKU S WITH (NOLOCK) ON S.SKU=OD.SKU   
                                 AND S.StorerKey = OD.StorerKey -- (Chee01)  
   WHERE pd.caseid=@c_caseid  
   group by L.lottable03     
  
   SELECT @n_CntLot03 = COUNT(1),  
          @c_Lott03 = Lottable03  
   FROM #COO  
   GROUP BY Lottable03     
  
   SELECT TOP 1 @n_cntsku = count(DISTINCT PD.SKU),  
              --  @c_Lott03 = L.lottable03,    
               -- @c_PDSKU = PD.SKU,  
              --  @c_SDESCR = s.descr,  
                @n_SumPickDETQTY = SUM(PD.Qty)  
 FROM ORDERDETAIL OD WITH (NOLOCK)   
 INNER JOIN PickDetail PD WITH (NOLOCK) ON PD.orderkey=OD.Orderkey AND PD.Storerkey=OD.Storerkey AND PD.SKU=OD.SKU  
 INNER JOIN lotattribute L WITH (NOLOCK) ON L.Lot=PD.Lot AND L.Storerkey=PD.Storerkey AND L.SKU=PD.SKU  
 INNER JOIN SKU S WITH (NOLOCK) ON S.SKU=OD.SKU  
                               AND S.StorerKey = OD.StorerKey -- (Chee01)  
 WHERE pd.caseid=@c_caseid  
 --group by L.lottable03,PD.SKU,s.descr  
  
    IF @n_cntsku = 1   
    BEGIN  
    SELECT @c_PDSKU = PD.SKU,  
           @c_SDESCR = s.descr  
           ,@c_ODUdf03 = OD.UserDefine01       --(CS03)  
     FROM ORDERDETAIL OD WITH (NOLOCK)   
  INNER JOIN PickDetail PD WITH (NOLOCK) ON PD.orderkey=OD.Orderkey AND PD.Storerkey=OD.Storerkey AND PD.SKU=OD.SKU  
  INNER JOIN lotattribute L WITH (NOLOCK) ON L.Lot=PD.Lot AND L.Storerkey=PD.Storerkey AND L.SKU=PD.SKU  
  INNER JOIN SKU S WITH (NOLOCK) ON S.SKU=OD.SKU  
                                  AND S.StorerKey = OD.StorerKey -- (Chee01)  
  WHERE pd.caseid=@c_caseid  
  
     UPDATE #Result            
     SET Col14 = @n_SumPickDETQTY,  
       --  Col16= @c_Lott03,  
         Col17= @c_PDSKU,  
         Col18 = '',  
         Col19=@c_SDESCR  
         ,col20 = @c_ODUdf03   --CS03  
      
    END  
    ELSE  
    BEGIN  
    UPDATE #Result            
     SET Col14 = @n_SumPickDETQTY,  
       --  Col16= '',  
         Col17= 'MIXED',  
         Col18 = 'MIXED',  
         Col19='MIXED'  
    END  
  
 IF @n_CntLot03 = 1   
 BEGIN  
  UPDATE #Result            
     SET Col16= @c_Lott03  
  END  
  ELSE  
  BEGIN  
   UPDATE #Result            
     SET Col16= ''  
  END  
         
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_caseid          
    
END -- While             
CLOSE CUR_RowNoLoop            
DEALLOCATE CUR_RowNoLoop          
            
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
   EXEC isp_InsertTraceInfo   
      @c_TraceCode = 'BARTENDER',  
      @c_TraceName = 'isp_BT_Bartender_Shipper_Label_DC',  
      @c_starttime = @d_Trace_StartTime,  
      @c_endtime = @d_Trace_EndTime,  
      @c_step1 = @c_UserName,  
      @c_step2 = '',  
      @c_step3 = '',  
      @c_step4 = '',  
      @c_step5 = '',  
      @c_col1 = @c_Sparm1,   
      @c_col2 = @c_Sparm2,  
      @c_col3 = @c_Sparm3,  
      @c_col4 = @c_Sparm4,  
      @c_col5 = @c_Sparm5,  
      @b_Success = 1,  
      @n_Err = 0,  
      @c_ErrMsg = ''              
   
select * from #result WITH (NOLOCK)  
                                  
END -- procedure    
  

GO
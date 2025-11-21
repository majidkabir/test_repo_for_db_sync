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
/* 2014-07-09 1.0  CSCHONG    Created(SOS 313797)                             */   
/* 2014-07-30 2.0  CSCHONG    Change the col18 field value (CS02)             */  
/* 2014-08-01 3.0  CSCHONG    Map col20 to new field (CS03)                   */  
/* 2014-08-14 4.0  CSCHONG    Change the col2,3,4 mapping (CS04)              */  
/* 2017-02-27 4.1  CSCHONG    Remove SET ANSI_WARNINGS OFF (CS05)             */  
/* 2017-04-07 4.2  CSCHONG    Performance tuning addd (NOLOCK) (CS06)         */  
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_Shipper_Label_DTC]                       
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
  -- SET ANSI_WARNINGS OFF            --CS05             
                              
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
      @n_CntLot03        INT,  
      @c_PLabelNo        NVARCHAR(80)  
  
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
    SET @n_SumPickDETQTY = 0            
    SET @n_SumUnitPrice = 0            
              
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
                 
            
  --SET @c_SQLJOIN = +' SELECT DISTINCT ORD.C_contact1 ,ORD.c_address1,ORD.c_address2,(ORD.c_address3+ORD.c_address4),ORD.c_city,'    --5      
    SET @c_SQLJOIN = +' SELECT DISTINCT TOP 1 ORD.C_contact1 ,Substring(DI.data,451,50) As Add1 ,Substring(DI.data,501,50) As Add2,Substring(DI.data,551,50) AS Add3,ORD.c_city,'    --5          
             + CHAR(13) +           
             +'ORD.c_zip ,ORD.c_country ,F.descr,(F.Address1+F.Address2+F.Address3+F.Address4),F.City,'  --5      
             + CHAR(13) +          
             +'F.State,F.Zip,F.country,ISNULL(c1.Description,''PARCEL DIRECT''),ISNULL(c2.Description,''PRIORITY''),'+ CHAR(13) +     --5     
             +'Ord.ExternOrderKey,Ord.OrderKey,CSD.TrackingNumber,ISNULL(c3.short,''''),ORD.C_State, '      --(CS02)  --(CS03)  
             + ' '''','''','''','''','''','    --25       
             +' '''','''','''','''','''','     --30        
             + CHAR(13) +          
             +' '''','''','''','''','''','''','''','''','''','''','   --40       
             +' '''','''','''','''','''','''','''','''','''','''', '  --50       
             +' '''','''','''','''','''','''','''','''','''','''' '   --60          
             + CHAR(13) +            
             + ' FROM ORDERS ORD WITH (NOLOCK) JOIN OrderDetail od WITH (NOLOCK) ON od.orderkey = ord.orderkey'    --(CS06)  
             + ' JOIN Facility F WITH (NOLOCK) ON F.facility=ORD.facility'       
            -- + ' FULL JOIN STORER sto WITH (NOLOCK) ON sto.storerkey = ORD.facility'        
             + ' JOIN SKU s WITH (NOLOCK) ON s.sku=od.sku'   
             + ' and s.storerkey = od.storerkey '   
           --  + ' JOIN pickdetail pd WITH (NOLOCK) ON pd.orderkey=ORD.orderkey'  
             + ' JOIN PACKHEADER PH WITH (NOLOCK) ON PH.loadkey = ORD.loadkey'  
             + ' JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno' --AND od.sku=od.sku' (Chee01)  
             + ' LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.storerkey = ORD.Storerkey AND C1.code=ORD.type and C1.LISTNAME=''AFDTCPddec'' '  
             + ' LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.storerkey = ORD.Storerkey AND C2.code=ORD.type and C2.LISTNAME=''AFDTCPdsl'' '  
             + ' LEFT JOIN CODELKUP C3 WITH (NOLOCK) ON C3.code=substring(s.itemclass,2,2) AND C3.LISTNAME=''AFDTCDept'' '  
             + ' LEFT JOIN CartonShipmentDetail CSD WITH (NOLOCK) ON CSD.Storerkey = Ord.Storerkey AND CSD.Orderkey = Ord.Orderkey AND CSD.loadkey=Ord.loadkey'         --(CS02)  
             + ' LEFT JOIN DOCINFO DI WITH (NOLOCK) ON DI.Key1=ORD.Orderkey AND DI.Storerkey=ORD.Storerkey AND DI.tablename=''Orders'' '  
             + ' WHERE ORD.LoadKey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm1+ '''),'''') <> '''' THEN ''' + @c_Sparm1+ ''' ELSE ORD.LoadKey END'--''' + @c_Sparm1+ ''' '    
             + ' AND ORD.OrderKey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm2+ '''),'''') <> '''' THEN ''' + @c_Sparm2+ ''' ELSE ORD.OrderKey END'    
             + ' AND ORD.ExternOrderkey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm3+ '''),'''') <> '''' THEN ''' + @c_Sparm3+ ''' ELSE ORD.ExternOrderkey END'    
             + ' AND PDET.labelno = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm4+ '''),'''') <> '''' THEN ''' + @c_Sparm4+ ''' ELSE PDET.labelno END'  
             + ' AND ORD.type = ''DTC'' '   
             + ' AND Ord.Storerkey = ''ANF'' '       
            -- + ' AND PDET.Dropid = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm5+ '''),'''') <> '''' THEN ''' + @c_Sparm5+ ''' ELSE PDET.Dropid END'         
             + ' group by ORD.C_contact1 ,Substring(DI.data,451,50),Substring(DI.data,501,50),Substring(DI.data,551,50),ORD.c_city,'   
             + ' ORD.c_zip ,ORD.c_country ,F.descr,(F.Address1+F.Address2+F.Address3+F.Address4),F.City,F.State,F.Zip,F.country,c1.Description,c2.Description,'  
             + 'Ord.ExternOrderKey,Ord.OrderKey,PDET.labelno,c3.short,CSD.TrackingNumber,ORD.C_State '         
          
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
              
      EXEC sp_executesql @c_SQL          
              
      IF @b_debug=1        
      BEGIN          
         PRINT @c_SQL          
      END        
      IF @b_debug=1        
      BEGIN        
         SELECT * FROM #Result (nolock)        
      END        
  
            
/*DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
          
SELECT DISTINCT col17,Col18 from #Result          
    
OPEN CUR_RowNoLoop            
    
FETCH NEXT FROM CUR_RowNoLoop INTO @c_OrderKey,@c_PLabelNo       
      
WHILE @@FETCH_STATUS <> -1            
BEGIN           
   IF @b_debug='1'        
   BEGIN        
      PRINT @c_OrderKey           
   END     
  
     
       IF @c_Sparm4 = 'DHL'  
       BEGIN  
         UPDATE #Result            
         SET Col18= 'HKANF' + @c_PLabelNo  
        END  
         
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_OrderKey,@c_PLabelNo        
    
END -- While             
CLOSE CUR_RowNoLoop            
DEALLOCATE CUR_RowNoLoop        */  
            
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
   EXEC isp_InsertTraceInfo   
      @c_TraceCode = 'BARTENDER',  
      @c_TraceName = 'isp_BT_Bartender_Shipper_Label_DTC',  
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
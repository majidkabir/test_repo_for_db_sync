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
/******************************************************************************/              
                
CREATE PROC [dbo].[isp_BT_Bartender_HK_Carton_Label_NIKE]                     
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
      @c_labelno         NVARCHAR(20), 
      @c_cntNo           NVARCHAR(5),       
      @c_ORDUDef10       NVARCHAR(20),
      @c_ORDUDef03       NVARCHAR(20),
      @c_ItemClass       NVARCHAR(10),
      @c_SKUGRP          NVARCHAR(10),
      @c_Style           NVARCHAR(20), 
      @n_intFlag         INT,   
      @n_CntRec          INT,
      @n_cntsku          INT,
      @c_Lott01          NVARCHAR(18),
      @c_Lott03          NVARCHAR(18),
      @c_Lott06          NVARCHAR(30),
      @c_Lott07          NVARCHAR(30),
      @c_Lott08          NVARCHAR(30),
      @c_ODSKU           NVARCHAR(20),
      @c_SALTSKU         NVARCHAR(20),
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
      @c_RefNo2          NVARCHAR(30),  
      @c_CntRefNo2       INT,
      @n_CntLabel        INT,
      @c_PStatus         NVARCHAR(1),
      @c_GetCol32        NVARCHAR(80) 

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
    SET @c_RefNo2 = ''  
    SET @n_CntLabel = 0
    SET @c_PStatus = ''
    
          
            
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
          
  SET @c_SQLJOIN = +'SELECT DISTINCT S.Company,ORD.Storerkey,ORD.ExternOrderKey,ORD.OrderKey,ORD.Stop,ORD.route,'
                   +' ORD.userdefine09,convert(nvarchar(10), ORD.deliverydate, 120),ORD.consigneekey,ORD.c_company,'
                   +' ORD.C_contact1,ORD.c_address1,ORD.c_address2,ORD.c_address3,ORD.c_address4,ORD.c_city,'        --16
                   +' ORD.c_zip,ORD.c_country,ORD.c_state,ORD.Notes,PD.Pickslipno,'
                   +' PD.Labelno,PD.CartonNo,'                                                                       --23
                   +' STUFF( (SELECT distinct '','' + RTRIM(loc.putawayzone) FROM LOC loc WITH (NOLOCK) INNER JOIN PICKDETAIL PDET WITH (NOLOCK) on PDET.loc = loc.loc '
                   + ' WHERE PDET.orderkey = PH.orderkey and PDET.dropid = PD.dropid FOR XML PATH('''')) ,1,1,'''' ), '
                   +'  STUFF( (SELECT distinct '','' + RTRIM(loc.putawayzone) FROM LOC loc WITH (NOLOCK) INNER JOIN PICKDETAIL PDET WITH (NOLOCK) on PDET.loc = loc.loc '
                   + ' WHERE PDET.orderkey = PH.orderkey  FOR XML PATH('''')) ,1,1,'''' ), '
                   +'  sum(PD.qty) ,'''','''','''','''','''','''','''','''','''', '  --35    --(CS03) 
                   +' '''','''','''','''','''','''','''','''','''','''' ,'''','''','''','''','''','   --50
                   +' '''','''','''','''','''','''','''','''','''','''' '                                --60
                   +' FROM ORDERS ORD WITH (NOLOCK) '
                   +' JOIN FACILITY F WITH (NOLOCK) ON F.facility = ORD.Facility'
                   +' LEFT JOIN MBOL MB WITH (NOLOCK) ON MB.Mbolkey = ORD.Mbolkey'
                   +' JOIN STORER S WITH (NOLOCK) ON S.storerkey = ORD.Storerkey'
                   +' JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = ORD.OrderKey'
                   +' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno ' 
                   +' LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.Pickslipno = PD.Pickslipno '
                   +' AND PIF.CartonNo = PD.CartonNo '    
--                   +' WHERE ORD.LoadKey =CASE WHEN ISNULL(RTRIM(''' + @c_Sparm1+ '''),'''') <> '''' THEN ''' + @c_Sparm1+ ''' ELSE ORD.loadkey END '   --(CS02)
--                   +' AND ORD.OrderKey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm2+ '''),'''') <> '''' THEN ''' + @c_Sparm2+ ''' ELSE ORD.OrderKey END'   --(CS02) 
--                   +' AND PD.Dropid = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm3+ '''),'''') <> '''' THEN ''' + @c_Sparm3+ ''' ELSE PD.Dropid END'         --(CS02) 
                   + ' WHERE ORD.Orderkey = ''' + @c_Sparm1+ ''''                                            --(CS02)
                   + ' AND PD.Labelno = ''' + @c_Sparm2+ ''' '                                 --(CS02)
                  -- + ' AND PD.Cartonno <= CONVERT(INT,''' + @c_Sparm3+ ''')'          --(CS02)
                   + ' GROUP BY ORD.storerkey, S.company, ORD.ExternOrderKey, ORD.OrderKey, ORD.stop, ORD.route, '
                   + ' ORD.userdefine09, ORD.deliverydate, ORD.consigneekey, '
                   + ' ORD.c_company, ORD.C_contact1, ORD.c_address1, ORD.c_address2, ORD.c_address3, ORD.c_address4,' 
                   + ' ORD.C_City, ORD.C_Zip, ORD.C_Country, ORD.C_State, ORD.notes, S.notes1,'
                   + ' PD.pickslipno, PD.labelno, PD.cartonno,PH.orderkey,PD.dropid '
                   + 'order by ORD.orderkey, PD.pickslipno, PD.cartonno'
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

EXIT_SP:  

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()
   
   EXEC isp_InsertTraceInfo 
      @c_TraceCode = 'BARTENDER',
      @c_TraceName = 'isp_BT_Bartender_HK_Carton_Label_NIKE',
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
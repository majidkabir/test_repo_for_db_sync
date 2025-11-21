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
/* 2013-06-21 1.0  CSCHONG    Created                                         */      
/* 2013-09-03 2.0  CSCHONG    Add in filter by orderkey (CS02)                */     
/* 2013-10-14 3.0  CSCHONG    Add new field col49 deliveryplace (CS03)        */     
/* 2013-10-16 4.0  CSCHONG    SOS#283668 Assign trackno    (CS04)             */      
/* 2013-10-18 5.0  CSCHONG    Add new field col15 and col50 (CS05)            */    
/* 2013-10-22 6.0  CSCHONG    Only print if userdefine04 is not null (CS06)   */     
/* 2013-11-06 7.0  CSCHONG    Change the sorting logic for qty=1 (CS07)       */           
/******************************************************************************/              
                
CREATE PROC [dbo].[isp_BT_Bartender_Shipper_Label1]                     
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
   SET ANSI_WARNINGS OFF                    
                            
   DECLARE                
      @c_OrderKey        NVARCHAR(10),                  
      @c_ExternOrderKey  NVARCHAR(10),            
      @c_Deliverydate    DATETIME,            
      @c_ConsigneeKey    NVARCHAR(15),            
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
      @c_Udef04          NVARCHAR(80),         --(CS04)    
      @c_TrackingNo      NVARCHAR(20),         --(CS04)     
      @n_RowRef          INT,                  --(CS04)    
      @c_CLong           NVARCHAR(250),        --(CS05)    
      @c_ORDAdd          NVARCHAR(150),        --(CS06)    
      @n_TTLPickQTY      INT,  
      @c_ShipperKey      NVARCHAR(15)     
      
    -- SET RowNo = 0           
    SET @c_SQL = ''      
    SET @n_SumPickDETQTY = 0          
    SET @n_SumUnitPrice = 0          
            
    CREATE TABLE [#Result] (           
    -- [ID]    [INT] IDENTITY(1,1) NOT NULL,                          
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
    
    CREATE TABLE [#PICK] (           
      [ID]          [INT] IDENTITY(1,1) NOT NULL,                          
      [OrderKey]    [NVARCHAR] (80) NULL,            
      [TTLPICKQTY]  [INT] NULL)              
      
IF ISNULL(@c_Sparm4,'0') > '0'      
 BEGIN        
  IF @c_Sparm4='1'          
  BEGIN        
  SET @c_SQLJOIN = +' SELECT ORD.loadkey,ORD.orderkey,ORD.externorderkey,ORD.type,buyerpo,salesman,ORD.facility,STO.Secondary,'    --8      
             + CHAR(13) +         
             +'STO.Company,STO.SUSR1,STO.SUSR2,(STO.Address1+STO.Address2+STO.Address3),ORD.Notes,ORD.Notes2,ORD.Storerkey,STO.State,'  --8      
             + CHAR(13) +        
             +'STO.City,STO.Zip,STO.Contact1,STO.Phone1,STO.phone2,ORD.Consigneekey,ORD.c_Company,ORD.c_Address1,'+ CHAR(13) +        
             +'ORD.c_Address2,ORD.C_Address3,ORD.C_Address4,ORD.C_State,ORD.C_City,ORD.C_Zip,ORD.C_Contact1,ORD.C_Phone1,'        
             +'ORD.C_Phone2,ORD.M_Company,ORD.Userdefine01,ORD.Userdefine02,ORD.Userdefine03,ORD.Userdefine04,ORD.Userdefine05,ORD.PmtTerm,'          
             + CHAR(13) +        
             +'ORD.InvoiceAmount,'''','''','         
             +'ORD.ShipperKey,STO.B_Company,(STO.B_Address1+STO.B_Address2+STO.B_Address3),STO.B_Contact1,STO.B_Phone1,ORD.DeliveryPlace,'''', '  --50  --CS03    
             +' '''','''','''','''','''','''','''','''',LOC.Logicallocation,LOC.LOC '      --CS07      
             + CHAR(13) +          
             + ' FROM ORDERS ORD WITH (NOLOCK) INNER JOIN ORDERDETAIL ORDDET WITH (NOLOCK)  ON ORD.ORDERKEY = ORDDET.ORDERKEY   '     
             + ' INNER JOIN STORER STO WITH (NOLOCK) ON STO.STORERKEY = ORD.STORERKEY '      
             + ' INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey = ORD.OrderKey and PD.OrderLineNumber = ORDDET.OrderLineNumber'      
             + ' INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.LOC = PD.LOC '    --CS07    
             + ' WHERE ORD.LoadKey =''' + @c_Sparm1+ ''' '      
             + ' AND ORD.OrderKey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm2+ '''),'''') <> '''' THEN ''' + @c_Sparm2+ ''' ELSE ORD.OrderKey END'   --(CS02)      
             + ' AND ORD.ShipperKey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm3+ '''),'''') <> '''' THEN ''' + @c_Sparm3+ ''' ELSE ORD.ShipperKey END'   --(CS02)      
          --   + ' AND PD.QTY = ''1'' '      
         
  END         
  ELSE        
  BEGIN         
  SET @c_SQLJOIN = +' SELECT ORD.loadkey,ORD.orderkey,ORD.externorderkey,ORD.type,buyerpo,salesman,ORD.facility,STO.Secondary,'    --8      
             + CHAR(13) +         
             +'STO.Company,STO.SUSR1,STO.SUSR2,(STO.Address1+STO.Address2+STO.Address3),ORD.Notes,ORD.Notes2,ORD.Storerkey,STO.State,'  --8      
             + CHAR(13) +        
             +'STO.City,STO.Zip,STO.Contact1,STO.Phone1,STO.phone2,ORD.Consigneekey,ORD.c_Company,ORD.c_Address1,'+ CHAR(13) +        
             +'ORD.c_Address2,ORD.C_Address3,ORD.C_Address4,ORD.C_State,ORD.C_City,ORD.C_Zip,ORD.C_Contact1,ORD.C_Phone1,'        
             +'ORD.C_Phone2,ORD.M_Company,ORD.Userdefine01,ORD.Userdefine02,ORD.Userdefine03,ORD.Userdefine04,ORD.Userdefine05,ORD.PmtTerm,'          
             + CHAR(13) +        
             +'ORD.InvoiceAmount,'''','''','         
             +'ORD.ShipperKey,STO.B_Company,(STO.B_Address1+STO.B_Address2+STO.B_Address3),STO.B_Contact1,STO.B_Phone1,ORD.DeliveryPlace,'''', '  --50 --CS03     
             +' '''','''','''','''','''','''','''','''','''','''' '         
             + CHAR(13) +          
             + ' FROM ORDERS ORD WITH (NOLOCK) '    
             + ' INNER JOIN STORER STO WITH (NOLOCK) ON STO.STORERKEY = ORD.STORERKEY '     
             + ' WHERE ORD.LoadKey =''' + @c_Sparm1+ ''' '      
             + ' AND ORD.OrderKey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm2+ '''),'''') <> '''' THEN ''' + @c_Sparm2+ ''' ELSE ORD.OrderKey END'   --(CS02)      
             + ' AND ORD.ShipperKey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm3+ '''),'''') <> '''' THEN ''' + @c_Sparm3+ ''' ELSE ORD.ShipperKey END'   --(CS02)      
  END       
 END      
 ELSE      
   BEGIN      
   SET @c_SQLJOIN = +' SELECT ORD.loadkey,ORD.orderkey,ORD.externorderkey,ORD.type,buyerpo,salesman,ORD.facility,STO.Secondary,'    --8      
             + CHAR(13) +         
             +'STO.Company,STO.SUSR1,STO.SUSR2,(STO.Address1+STO.Address2+STO.Address3),ORD.Notes,ORD.Notes2,ORD.Storerkey,STO.State,'  --8      
             + CHAR(13) +        
             +'STO.City,STO.Zip,STO.Contact1,STO.Phone1,STO.phone2,ORD.Consigneekey,ORD.c_Company,ORD.c_Address1,'+ CHAR(13) +        
             +'ORD.c_Address2,ORD.C_Address3,ORD.C_Address4,ORD.C_State,ORD.C_City,ORD.C_Zip,ORD.C_Contact1,ORD.C_Phone1,'        
             +'ORD.C_Phone2,ORD.M_Company,ORD.Userdefine01,ORD.Userdefine02,ORD.Userdefine03,ORD.Userdefine04,ORD.Userdefine05,ORD.PmtTerm,'          
             + CHAR(13) +        
             +'ORD.InvoiceAmount,'''','''','         
             +'ORD.ShipperKey,STO.B_Company,(STO.B_Address1+STO.B_Address2+STO.B_Address3),STO.B_Contact1,STO.B_Phone1,ORD.DeliveryPlace,'''', '  --50  --CS03    
             +' '''','''','''','''','''','''','''','''','''','''' '         
             + CHAR(13) +          
             + ' FROM ORDERS ORD (NOLOCK) INNER JOIN STORER STO (NOLOCK) ON STO.STORERKEY = ORD.STORERKEY '      
             + ' WHERE ORD.LoadKey =''' + @c_Sparm1+ ''' '      
              + ' AND ORD.OrderKey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm2+ '''),'''') <> '''' THEN ''' + @c_Sparm2+ ''' ELSE ORD.OrderKey END'   --(CS02)      
             + ' AND ORD.ShipperKey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm3+ '''),'''') <> '''' THEN ''' + @c_Sparm3+ ''' ELSE ORD.ShipperKey END'   --(CS02)      
   END      
--END        
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
          
DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
        
SELECT DISTINCT col02,col38 from #Result        
  
OPEN CUR_RowNoLoop          
  
FETCH NEXT FROM CUR_RowNoLoop INTO @c_OrderKey,@c_Udef04       
    
WHILE @@FETCH_STATUS <> -1          
BEGIN         
   IF @b_debug='1'      
   BEGIN      
      PRINT @c_OrderKey         
   END      
   --  SELECT @n_SumPICKDETQty = SUM(QTY)          
   --  FROM PICKDETAIL PD (NOLOCK)          
   --   WHERE PD.OrderKey=@c_OrderKey          
       
   SELECT @n_SumPICKDETQty = SUM(QTY),          
        @n_SumUnitPrice = SUM(QTY * ORDDET.Unitprice)          
   FROM PICKDETAIL PD (NOLOCK) JOIN ORDERDETAIL ORDDET (NOLOCK)          
   ON PD.OrderKey = ORDDET.OrderKey and PD.OrderLineNumber = ORDDET.OrderLineNumber          
   WHERE PD.OrderKey=@c_OrderKey        
      
   /*CS04 Start*/    
   IF ISNULL(@c_Udef04,'') = ''    
   BEGIN    
      SET @c_TrackingNo = ''    
      SET @n_RowRef = 0    
  
      SELECT TOP 1 @c_TrackingNo = CT.TrackingNO,    
            @n_RowRef     = CT.RowRef    
      FROM ORDERS ORD WITH (NOLOCK)   
      JOIN CARTONTRACK CT WITH (NOLOCK) ON ORD.ShipperKey = CT.CarrierName    
      JOIN STORER STO WITH (NOLOCK) ON STO.Secondary = CT.Keyname and STO.Storerkey=ORD.Storerkey    
      WHERE ORD.OrderKey = @c_OrderKey    
      AND Isnull(CT.CarrierRef2,'')=''    
      ORDER BY CT.RowRef     
        
       IF @b_debug = '1'    
       BEGIN    
         PRINT 'Tracking no : ' + @c_TrackingNo + ' For Orderkey : ' + @c_OrderKey    
         PRINT ' RowRef No : ' + convert(varchar(10),@n_RowRef)      
       END    
  
      UPDATE ORDERS WITH (ROWLOCK)    
      SET Userdefine04 = @c_TrackingNo, TrafficCop = NULL      
      WHERE ORDERKEY = @c_OrderKey    
  
      UPDATE CARTONTRACK WITH (ROWLOCK)    
      SET LabelNo = @c_OrderKey, CarrierRef2 = 'GET'     
      WHERE RowRef = @n_RowRef    
  
      UPDATE #Result          
      SET Col38 = @c_TrackingNo         --(CS04)        
      WHERE Col02=@c_OrderKey     
   END    
   /*CS04 End*/    
      
           
   UPDATE #Result          
   SET Col42 = @n_SumPICKDETQty, COL43=@n_SumUnitPrice        
   WHERE Col02=@c_OrderKey       
  
  
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_OrderKey,@c_Udef04       
  
END -- While           
CLOSE CUR_RowNoLoop          
DEALLOCATE CUR_RowNoLoop        
    
SET @c_ORDAdd = ''    
DECLARE CUR_UpdateRec CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
SELECT DISTINCT col02   
FROM #Result        
  
OPEN CUR_UpdateRec          
  
FETCH NEXT FROM CUR_UpdateRec INTO @c_OrderKey       
    
WHILE @@FETCH_STATUS <> -1          
BEGIN     
   SET @c_ShipperKey = ''  
   SET @c_ORDAdd = ''  
        
   SELECT @c_ORDAdd = RTRIM(ORD.C_State) + ' ' + RTRIM(ORD.C_City) + ' ' + RTRIM(ORD.C_Address1)      
   FROM ORDERS ORD WITH (NOLOCK)    
   WHERE ORD.Orderkey =   @c_OrderKey      
  
   IF @b_debug = '1'    
   BEGIN     
      PRINT ' ORD address combine : ' + @c_ORDAdd + ' with orderkey : ' + @c_OrderKey    
   END  
    
   SET @c_CLong = ''  
   SELECT TOP 1  
      @c_CLong = C.Long    
   FROM Codelkup C WITH (NOLOCK)   
   LEFT OUTER JOIN ORDERS ORD WITH (NOLOCK) ON ORD.ShipperKey = C.Short    
   WHERE ORD.Orderkey =  @c_OrderKey    
   AND C.Listname='COURIERMAP'   
   AND C.UDF01='ELABEL'      
   AND C.Notes like N'%' + @c_ORDAdd + '%'      
  
   IF @b_debug = '1'    
   BEGIN     
      PRINT ' codelkup long : ' + @c_CLong + ' with orderkey : ' + @c_OrderKey    
   END    
    
   UPDATE #Result WITH (ROWLOCK)      
      SET Col50= @c_CLong      
   WHERE Col02=@c_OrderKey      
    
   FETCH NEXT FROM CUR_UpdateRec INTO @c_OrderKey       
  
END -- While        
    --      
CLOSE CUR_UpdateRec          
DEALLOCATE CUR_UpdateRec      
    
/*CS07 start*/     
INSERT INTO #PICK (OrderKey,TTLPICKQTY)    
SELECT DISTINCT col02,convert(INT,col42)    
FROM #RESULT WITH (NOLOCK)    
       
     
IF @b_Debug = '1'  
BEGIN  
    SELECT *  
    FROM   #PICK WITH (NOLOCK)  
END    
  
/*CS07 End*/    
IF ISNULL(@c_Sparm4 ,0) <> 0 
BEGIN  
    IF @c_Sparm4 = '1'  
    BEGIN  
        SELECT R.*   
        FROM   #Result R WITH (NOLOCK)  
               INNER JOIN #PICK P WITH (NOLOCK)  
                    ON  P.Orderkey = R.Col02  
        WHERE  ISNULL(Col38 ,'') <> '' --CS06  
        AND    P.TTLPICKQTY = 1  
        ORDER BY col59,col60,col02 --CS07  
    END  
    ELSE    
    IF @c_Sparm4 > '1'  
    BEGIN  
        SELECT R.*   
        FROM   #Result R WITH (NOLOCK)  
        INNER JOIN #PICK P WITH (NOLOCK) ON  P.Orderkey = R.Col02  
        WHERE  ISNULL(Col38 ,'') <> '' --CS06  
        AND    P.TTLPICKQTY > 1  
        ORDER BY col02  
    END  
END  
ELSE  
BEGIN  
    SELECT *  
    FROM   #Result WITH (NOLOCK)  
    WHERE  ISNULL(Col38 ,'') <> '' --CS06  
    ORDER BY Col02  
END                 
            
EXIT_SP:             
                                  
END -- procedure

GO
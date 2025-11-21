SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: BarTender Filter by ShipperKey                                    */  
/*          Copy from isp_BT_Bartender_Shipper_Label_SKS                      */               
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2019-09-17 1.0  WLCHOOI    Created (WMS-10496)                             */
/* 2021-04-02 1.1  CSCHONG    WMS-16024 PB-Standardize TrackingNo (CS01)      */  
/******************************************************************************/                                 
CREATE PROC [dbo].[isp_BT_Bartender_Shipper_Label_BL]                       
(  @c_Sparm1            NVARCHAR(250),              
   @c_Sparm2            NVARCHAR(250),              
   @c_Sparm3            NVARCHAR(250), 
   @c_Sparm4            NVARCHAR(250)='',  
   @c_Sparm5            NVARCHAR(250)='',    
   @c_Sparm6            NVARCHAR(250)='',  
   @c_Sparm7            NVARCHAR(250)='', 
   @c_Sparm8            NVARCHAR(250)='',  
   @c_Sparm9            NVARCHAR(250)='', 
   @c_Sparm10           NVARCHAR(250)='',                
   @b_debug             INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                
   --SET ANSI_WARNINGS OFF                                   
                              
   DECLARE                  
      @c_OrderKey        NVARCHAR(10),                    
      @c_ExternOrderKey  NVARCHAR(50),              
      @c_Deliverydate    DATETIME,              
      @c_ConsigneeKey    NVARCHAR(15),              
      @c_Company  NVARCHAR(45),              
      @C_Address1        NVARCHAR(45),              
      @C_Address2        NVARCHAR(45),              
      @C_Address3        NVARCHAR(45),              
      @C_Address4        NVARCHAR(45),              
      @C_BuyerPO         NVARCHAR(20),              
      @C_notes2          NVARCHAR(4000),              
      @c_OrderLineNo     NVARCHAR(5),              
      @c_SKU             NVARCHAR(20),  
      @c_ORDDETSKU       NVARCHAR(20), 
      @n_ORIQty          INT,           
      @n_Qty             INT,              
      @c_PackKey         NVARCHAR(10),              
      @c_UOM             NVARCHAR(10),              
      @C_PHeaderKey      NVARCHAR(18),              
      @C_SODestination   NVARCHAR(30)  
        
  DECLARE @n_RowNo             INT,  
          @n_SumPickDETQTY     INT,  
          @n_SumUnitPrice      INT,  
          @c_SQL               NVARCHAR(4000),  
          @c_SQLSORT           NVARCHAR(4000),  
          @c_SQLJOIN           NVARCHAR(4000),  
          @c_Udef04            NVARCHAR(80),       
          @c_TrackingNo        NVARCHAR(20),        
          @n_RowRef            INT,               
          @c_CLong             NVARCHAR(250),      
          @c_ORDAdd            NVARCHAR(150),      
          @n_TTLPickQTY        INT,  
          @c_ShipperKey        NVARCHAR(15),  
          @n_PackInfoWgt       INT,              
          @n_CntPickZone       INT,                
          @c_UDF01    NVARCHAR(60),      
          @c_consigneeFor      NVARCHAR(15),      
          @c_notes             NVARCHAR(80),       
          @c_City              NVARCHAR(45),        
          @c_GetCol55          NVARCHAR(100),      
          @c_Col55             NVARCHAR(80),     
          @c_ExecStatements    NVARCHAR(4000),     
          @c_ExecArguments     NVARCHAR(4000),      
          @c_picknotes         NVARCHAR(100),       
          @c_State             NVARCHAR(45),         
          @c_col35             NVARCHAR(80),         
          @c_StorerKey         NVARCHAR(15),        
          @c_Door              NVARCHAR(10),         
          @c_deliveryNote      NVARCHAR(10),         
          @c_GetShipperKey     NVARCHAR(15),          
          @c_GetCodelkup       NVARCHAR(1),            
          @c_cNotes            NVARCHAR(200),            
          @c_short             NVARCHAR(25),
          @c_PICKDETLOC        NVARCHAR(10),
          @c_SKUStyle          NVARCHAR(20),      
          @c_SKUBusr1          NVARCHAR(30),      
          @c_DeliveryRoute     NVARCHAR(80),      
          @c_DischargePlace    NVARCHAR(80),
          @c_DeliveryPlace     NVARCHAR(80)
          
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_condition1        NVARCHAR(150),    
           @c_condition2        NVARCHAR(150),    
           @c_EncryptPhoneNum  NVARCHAR(10) = 'N' 
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''        
    SET @n_SumPickDETQTY = 0            
    SET @n_SumUnitPrice = 0  

    SET @c_StorerKey = ''
    SET @c_Door = ''     
    SET @c_deliveryNote = ''
    SET @c_GetCodelkup = 'N'  
    SET @c_ORDDETSKU = ''  
    SET @n_ORIQTY = 0  
    
    SET @c_condition1 =''       
    SET @c_condition2 = ''      
               
    CREATE TABLE [#Result]  
    (  
     [ID]        [INT] IDENTITY(1, 1) NOT NULL,  
     [Col01]     [NVARCHAR] (80) NULL,  
     [Col02]     [NVARCHAR] (80) NULL,  
     [Col03]     [NVARCHAR] (80) NULL,  
     [Col04]     [NVARCHAR] (80) NULL,  
     [Col05]     [NVARCHAR] (80) NULL,  
     [Col06]     [NVARCHAR] (80) NULL,  
     [Col07]     [NVARCHAR] (80) NULL,  
     [Col08]     [NVARCHAR] (80) NULL,  
     [Col09]     [NVARCHAR] (80) NULL,  
     [Col10]     [NVARCHAR] (80) NULL,  
     [Col11]     [NVARCHAR] (80) NULL,  
     [Col12]     [NVARCHAR] (80) NULL,  
     [Col13]     [NVARCHAR] (80) NULL,  
     [Col14]     [NVARCHAR] (80) NULL,  
     [Col15]     [NVARCHAR] (80) NULL,  
     [Col16]     [NVARCHAR] (80) NULL,  
     [Col17]     [NVARCHAR] (80) NULL,  
     [Col18]     [NVARCHAR] (80) NULL,  
     [Col19]     [NVARCHAR] (80) NULL,  
     [Col20]     [NVARCHAR] (80) NULL,  
     [Col21]     [NVARCHAR] (80) NULL,  
     [Col22]     [NVARCHAR] (80) NULL,  
     [Col23]     [NVARCHAR] (80) NULL,  
     [Col24]     [NVARCHAR] (80) NULL,  
     [Col25]     [NVARCHAR] (80) NULL,  
     [Col26]     [NVARCHAR] (80) NULL,  
     [Col27]     [NVARCHAR] (80) NULL,  
     [Col28]     [NVARCHAR] (80) NULL,  
     [Col29]     [NVARCHAR] (80) NULL,  
     [Col30]     [NVARCHAR] (80) NULL,  
     [Col31]     [NVARCHAR] (80) NULL,  
     [Col32]     [NVARCHAR] (80) NULL,  
     [Col33]     [NVARCHAR] (80) NULL,  
     [Col34]     [NVARCHAR] (80) NULL,  
     [Col35]     [NVARCHAR] (80) NULL,  
     [Col36]     [NVARCHAR] (80) NULL,  
     [Col37]     [NVARCHAR] (80) NULL,  
     [Col38]     [NVARCHAR] (80) NULL,  
     [Col39]     [NVARCHAR] (80) NULL,  
     [Col40]     [NVARCHAR] (80) NULL,  
     [Col41]     [NVARCHAR] (80) NULL,  
     [Col42]     [NVARCHAR] (80) NULL,  
     [Col43]     [NVARCHAR] (80) NULL,  
     [Col44]     [NVARCHAR] (80) NULL,  
     [Col45]     [NVARCHAR] (80) NULL,  
     [Col46]     [NVARCHAR] (80) NULL,  
     [Col47]     [NVARCHAR] (80) NULL,  
     [Col48]     [NVARCHAR] (80) NULL,  
     [Col49]     [NVARCHAR] (80) NULL,  
     [Col50]     [NVARCHAR] (80) NULL,  
     [Col51]     [NVARCHAR] (80) NULL,  
     [Col52]     [NVARCHAR] (80) NULL,  
     [Col53]     [NVARCHAR] (80) NULL,  
     [Col54]     [NVARCHAR] (80) NULL,  
     [Col55]     [NVARCHAR] (80) NULL,  
     [Col56]     [NVARCHAR] (80) NULL,  
     [Col57]     [NVARCHAR] (80) NULL,  
     [Col58]     [NVARCHAR] (80) NULL,  
     [Col59]     [NVARCHAR] (80) NULL,  
     [Col60]     [NVARCHAR] (80) NULL  
    )            
      
    CREATE TABLE [#PICK]  
    (  
     [ID]             [INT] IDENTITY(1, 1) NOT NULL,  
     [OrderKey]       [NVARCHAR] (80) NULL,  
     [TTLPICKQTY]     [INT] NULL,  
     [PickZone]       [INT] NULL,  
     [picknotes]      [nvarchar] (100) NULL   --(CS16)  
    
    )                
    
    
    
   IF ISNULL(RTRIM(@c_Sparm2),'') <> ''
   BEGIN
   	SET @c_condition1 = ' AND ORD.OrderKey =RTRIM(@c_Sparm2)'
   END   
   
   IF ISNULL(RTRIM(@c_Sparm3),'') <> ''
   BEGIN
   	SET @c_condition2 = ' AND ORD.ShipperKey =RTRIM(@c_Sparm3)'
   END      
        
IF ISNULL(@c_Sparm4,'0') > '0'        
 BEGIN          
  IF @c_Sparm4='1'            
   BEGIN          
     SET @c_SQLJOIN = +' SELECT ORD.loadkey,ORD.orderkey,ORD.externorderkey,ORD.type,buyerpo,salesman,ORD.facility,STO.Secondary,'    --8        
                + CHAR(13) +           
                +'STO.Company,STO.SUSR1,STO.SUSR2,(STO.Address1+STO.Address2+STO.Address3),Substring(ORD.Notes,1,80),'''',ORD.StorerKey,STO.State,'  --8   --CS05   
                + CHAR(13) +          
                +'STO.City,STO.Zip,STO.Contact1,STO.Phone1,STO.phone2,ORD.Consigneekey,ORD.c_Company,ORD.c_Address1,'+ CHAR(13) +          
                +'ISNULL(ORD.c_Address2,''''),ISNULL(ORD.C_Address3,''''),ORD.C_Address4,ORD.C_State,ORD.C_City,ORD.C_Zip,ORD.C_Contact1,ORD.C_Phone1,'          
                +'ISNULL(ORD.C_Phone2,''''),ORD.M_Company,ORD.Userdefine01,'--ORD.Userdefine02,'                                                       --CS06
                + 'CASE WHEN STO.Storerkey = ''18354'' THEN ORDIF.DeliveryCategory ELSE ORD.Userdefine02 END, '                                        --CS06
                +' CASE WHEN STO.VAT=''ITX'' THEN ORD.door ELSE  ORD.Userdefine03 END,'
                +' ORD.trackingno,ORD.Userdefine05,'--ORD.PmtTerm,'            --CS01
                +' CASE WHEN STO.Storerkey IN (''ANF'',''18354'') THEN ORD.DeliveryNote Else ORD.PmtTerm END ,'      --CS06
                + CHAR(13) +          
                +'ORD.InvoiceAmount,'''','''','           
                +'ORD.ShipperKey,'''','''','''','''',ORD.DeliveryPlace,'''', '  --50       
                +' '''',ORD.M_Address1,ORD.M_Address2,ORD.M_City,'''','''',ORD.Priority,ORD.Userdefine10,LOC.Logicallocation,LOC.LOC '      
                + CHAR(13) +            
                + ' FROM ORDERS ORD WITH (NOLOCK) INNER JOIN ORDERDETAIL ORDDET WITH (NOLOCK)  ON ORD.ORDERKEY = ORDDET.ORDERKEY   '       
                + ' INNER JOIN STORER STO WITH (NOLOCK) ON STO.StorerKey = ORD.StorerKey '        
                + ' INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey = ORD.OrderKey and PD.OrderLineNumber = ORDDET.OrderLineNumber'        
                + ' INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.LOC = PD.LOC '   
                + ' LEFT JOIN ORDERINFO ORDIF WITH (NOLOCK) ON ORDIF.orderkey = ORD.Orderkey '                                    --CS06       
                + ' WHERE ORD.LoadKey = @c_Sparm1 '        
               -- + ' AND ORD.OrderKey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm2+ '''),'''') <> '''' THEN ''' + @c_Sparm2+ ''' ELSE ORD.OrderKey END'        
              --  + ' AND ORD.ShipperKey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm3+ '''),'''') <> '''' THEN ''' + @c_Sparm3+ ''' ELSE ORD.ShipperKey END'         
             --   + ' AND PD.QTY = ''1'' '        
              
   END           
  ELSE          
  BEGIN           
     SET @c_SQLJOIN = +' SELECT ORD.loadkey,ORD.orderkey,ORD.externorderkey,ORD.type,buyerpo,salesman,ORD.facility,STO.Secondary,'    --8        
                + CHAR(13) +           
                +'STO.Company,STO.SUSR1,STO.SUSR2,(STO.Address1+STO.Address2+STO.Address3),substring(ORD.Notes,1,80),'''',ORD.StorerKey,STO.State,'  --8      --CS05 
                + CHAR(13) +          
                +'STO.City,STO.Zip,STO.Contact1,STO.Phone1,STO.phone2,ORD.Consigneekey,ORD.c_Company,ORD.c_Address1,'+ CHAR(13) +          
                +'ISNULL(ORD.c_Address2,''''),ISNULL(ORD.C_Address3,''''),ORD.C_Address4,ORD.C_State,ORD.C_City,ORD.C_Zip,ORD.C_Contact1,ORD.C_Phone1,'          
                +'ISNULL(ORD.C_Phone2,''''),ORD.M_Company,ORD.Userdefine01,'--ORD.Userdefine02,'                                                       --CS06
                + 'CASE WHEN STO.Storerkey = ''18354'' THEN ORDIF.DeliveryCategory ELSE ORD.Userdefine02 END, '                                        --CS06
                +' CASE WHEN STO.VAT=''ITX'' THEN ORD.door ELSE  ORD.Userdefine03 END,'
                +' ORD.trackingno,ORD.Userdefine05,'--ORD.PmtTerm,'      --CS01     
                +' CASE WHEN STO.Storerkey IN (''ANF'',''18354'') THEN ORD.DeliveryNote Else ORD.PmtTerm END ,'      --CS06
                + CHAR(13) +          
                +'ORD.InvoiceAmount,'''','''','           
                +'ORD.ShipperKey,'''','''','''','''',ORD.DeliveryPlace,'''', '  --50        
                +' '''',ORD.M_Address1,ORD.M_Address2,ORD.M_City,'''','''',ORD.Priority,ORD.Userdefine10,'''','''' '   
                + CHAR(13) +            
                + ' FROM ORDERS ORD WITH (NOLOCK) '      
                + ' INNER JOIN STORER STO WITH (NOLOCK) ON STO.StorerKey = ORD.StorerKey '   
                + ' LEFT JOIN ORDERINFO ORDIF WITH (NOLOCK) ON ORDIF.orderkey = ORD.Orderkey '                                    --CS33      
                + ' WHERE ORD.LoadKey = @c_Sparm1 '        
             --   + ' AND ORD.OrderKey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm2+ '''),'''') <> '''' THEN ''' + @c_Sparm2+ ''' ELSE ORD.OrderKey END'           
              --  + ' AND ORD.ShipperKey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm3+ '''),'''') <> '''' THEN ''' + @c_Sparm3+ ''' ELSE ORD.ShipperKey END'         
  END         
 END        
 ELSE        
 BEGIN        
   SET @c_SQLJOIN = +' SELECT ORD.loadkey,ORD.orderkey,ORD.externorderkey,ORD.type,buyerpo,salesman,ORD.facility,STO.Secondary,'    --8        
             + CHAR(13) +           
             +'STO.Company,STO.SUSR1,STO.SUSR2,(STO.Address1+STO.Address2+STO.Address3),substring(ORD.Notes,1,80),'''',ORD.StorerKey,STO.State,'  --8     --CS05
             + CHAR(13) +          
             +'STO.City,STO.Zip,STO.Contact1,STO.Phone1,STO.phone2,ORD.Consigneekey,ORD.c_Company,ORD.c_Address1,'+ CHAR(13) +          
             +'ISNULL(ORD.c_Address2,''''),ISNULL(ORD.C_Address3,''''),ORD.C_Address4,ORD.C_State,ORD.C_City,ORD.C_Zip,ORD.C_Contact1,ORD.C_Phone1,'          
             +'ISNULL(ORD.C_Phone2,''''),ORD.M_Company,ORD.Userdefine01,'--ORD.Userdefine02,'                                                       --CS06
             + 'CASE WHEN STO.Storerkey = ''18354'' THEN ORDIF.DeliveryCategory ELSE ORD.Userdefine02 END, '                                        --CS06
             +' CASE WHEN STO.VAT=''ITX'' THEN ORD.door ELSE  ORD.Userdefine03 END,'
             +' ORD.trackingno,ORD.Userdefine05,'--ORD.PmtTerm,'       --CS01   
             +' CASE WHEN STO.Storerkey IN (''ANF'',''18354'') THEN ORD.DeliveryNote Else ORD.PmtTerm END ,'      --CS06
             + CHAR(13) +          
             +'ORD.InvoiceAmount,'''','''','           
             +'ORD.ShipperKey,'''','''','''','''',ORD.DeliveryPlace,'''', '       
             +' '''',ORD.M_Address1,ORD.M_Address2,ORD.M_City,'''','''',ORD.Priority,ORD.Userdefine10,'''','''' '       
             + CHAR(13) +            
             + ' FROM ORDERS ORD (NOLOCK) INNER JOIN STORER STO (NOLOCK) ON STO.StorerKey = ORD.StorerKey '   
             + ' LEFT JOIN ORDERINFO ORDIF WITH (NOLOCK) ON ORDIF.orderkey = ORD.Orderkey '                                    --CS33       
             + ' WHERE ORD.LoadKey = @c_Sparm1 '        
            -- + ' AND ORD.OrderKey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm2+ '''),'''') <> '''' THEN ''' + @c_Sparm2+ ''' ELSE ORD.OrderKey END'           --CS06   
            -- + ' AND ORD.ShipperKey = CASE WHEN ISNULL(RTRIM(''' + @c_Sparm3+ '''),'''') <> '''' THEN ''' + @c_Sparm3+ ''' ELSE ORD.ShipperKey END'        
 END        
--END          
      IF @b_debug = 1  
      BEGIN  
          PRINT @c_SQLJOIN  
      END               
              
  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +           
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +           
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +           
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +           
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +           
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '          
    
   SET @c_SQL = @c_SQL + @c_SQLJOIN +  CHAR(13) + @c_condition1  + CHAR(13) + @c_condition2     --CS06      
        
    --CS06 start
   SET @c_ExecArguments = N'   @c_Sparm1           NVARCHAR(80)'    
                          + ', @c_Sparm2           NVARCHAR(80) '    
                          + ', @c_Sparm3           NVARCHAR(80)'   
                         
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Sparm1    
                        , @c_Sparm2    
                        , @c_Sparm3   
                        
     
   --EXEC sp_executesql @c_SQL      
   --CS06 END       
        
   IF @b_debug = 1  
   BEGIN  
       PRINT @c_SQL  
   END  
  
   IF @b_debug = 1  
   BEGIN  
       SELECT *  
       FROM   #Result(NOLOCK)  
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
      
   IF @c_Sparm4 < '8'  
   BEGIN  
       SELECT @n_SumPICKDETQty = SUM(QTY),  
              @n_SumUnitPrice = SUM(QTY * ORDDET.Unitprice)  
       FROM   PICKDETAIL PD(NOLOCK)  
              JOIN ORDERDETAIL ORDDET(NOLOCK)  
                   ON  PD.OrderKey = ORDDET.OrderKey  
                   AND PD.OrderLineNumber = ORDDET.OrderLineNumber  
       WHERE  PD.OrderKey = @c_OrderKey  
   END  
   ELSE  
   BEGIN  
       SELECT @n_SumPICKDETQty    = SUM(QTY),  
              @n_SumUnitPrice     = SUM(QTY * ORDDET.Unitprice),  
              @n_cntPickzone      = COUNT(DISTINCT l.pickzone)  
              --@c_picknotes        = PD.notes  
       FROM   PICKDETAIL PD WITH (NOLOCK)  
              JOIN ORDERDETAIL ORDDET WITH (NOLOCK)  
                   ON  PD.OrderKey = ORDDET.OrderKey  
                   AND PD.OrderLineNumber = ORDDET.OrderLineNumber  
              JOIN LOC L WITH (NOLOCK)  
                   ON  L.LOC = PD.LOC  
       WHERE  PD.OrderKey = @c_OrderKey  
       --GROUP BY PD.notes  
         
       SELECT TOP 1 @c_picknotes = PD.notes   
        FROM   PICKDETAIL PD WITH (NOLOCK)  
              JOIN ORDERDETAIL ORDDET WITH (NOLOCK)  
                   ON  PD.OrderKey = ORDDET.OrderKey  
                   AND PD.OrderLineNumber = ORDDET.OrderLineNumber  
              JOIN LOC L WITH (NOLOCK)  
                   ON  L.LOC = PD.LOC  
       WHERE  PD.OrderKey = @c_OrderKey  
  
         
   END  

   SELECT @n_PackInfoWgt = SUM(PKI.Weight) 
   FROM   PACKHeader PH WITH (NOLOCK)  
          JOIN Orders ORD WITH (NOLOCK)  
               ON  ORD.OrderKey = PH.OrderKey  
          JOIN PACKINFO PKI WITH (NOLOCK)  
               ON  PKI.Pickslipno = PH.pickslipno  
   WHERE  PH.OrderKey = @c_OrderKey     
  

   SELECT TOP 1 @c_col35 = CASE WHEN S.VAT = 'ITX' THEN CAST(SUM(CAST(PKI.[Cube] as NUMERIC(6,6))) as NVARCHAR(30)) ELSE MAX(ORD.Userdefine01) END   
   FROM   PACKHeader PH WITH (NOLOCK)  
          JOIN Orders ORD WITH (NOLOCK)  
               ON  ORD.OrderKey = PH.OrderKey  
          JOIN PACKINFO PKI WITH (NOLOCK)  
               ON  PKI.Pickslipno = PH.pickslipno  
          JOIN Storer S WITH (NOLOCK) ON S.StorerKey = ORD.StorerKey
   WHERE  PH.OrderKey = @c_OrderKey 
   GROUP BY S.VAT,PKI.[Cube],ORD.Userdefine01 
  

   SELECT @n_ORIQTY = SUM(OriginalQTY)
   FROM ORDERDETAIL ORDDET WITH (NOLOCK)
   WHERE Orderkey = @c_OrderKey


   SET @c_ORDDETSKU = ''
   SET @c_PICKDETLOC = ''
   SET @c_SKUStyle  = ''    
   SET @c_SKUBusr1  = ''    

   IF @n_ORIQTY = 1
   BEGIN
 
    SELECT TOP 1 @c_ORDDETSKU = ORDDET.SKU
    FROM ORDERDETAIL ORDDET WITH (NOLOCK)
    WHERE Orderkey = @c_OrderKey
 
   /*CS02 Start*/

   SELECT TOP 1 @c_PICKDETLOC = PDET.LOC
   FROM PICKDETAIL PDET WITH (NOLOCK)
   WHERE PDET.Orderkey=@c_OrderKey

  /*CS02 End*/
  /*CS03 start*/
    SELECT TOP 1 @c_SKUStyle = S.Style,
                 @c_SKUBusr1 = S.busr1
    FROM ORDERDETAIL ORDDET WITH (NOLOCK)
    JOIN SKU S WITH (NOLOCK) ON S.Sku = ORDDET.SKU
    WHERE Orderkey = @c_OrderKey
   /*CS03 End*/

    IF @b_debug='1'        
         BEGIN        
            PRINT 'skustyle  : '  + @c_SKUStyle  + ' sku busr1 : '  + @c_SKUBusr1     
         END     

   END
               
   UPDATE #Result            
   SET Col42 = @n_SumPICKDETQty,   
       COL43 = @n_SumUnitPrice,  
       Col56 = @n_PackInfoWgt,    
       Col35 = @c_Col35,               
       Col45 = @c_ORDDETSKU,
       Col46 = @c_PICKDETLOC,
       Col47 = @c_SKUStyle,    
       Col48 = @c_SKUBusr1     
   WHERE Col02=@c_OrderKey         
    
  
  INSERT INTO #PICK (OrderKey,TTLPICKQTY,PickZone,picknotes)      
  VALUES (@c_OrderKey,convert(int,@n_SumPICKDETQty),ISNULL(@n_cntPickzone,0),@c_picknotes)  
  
   
  IF @b_Debug = '1'    
  BEGIN    
    SELECT 'Pick'  
    SELECT *    
    FROM   #PICK WITH (NOLOCK)    
  END    
    
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
         ,@c_city = RTRIM(ORD.C_City)                      
         ,@c_State = RTRIM(ORD.C_State)                   
         ,@c_Address1 = RTRIM(ORD.C_Address1)               
         ,@c_StorerKey = ORD.StorerKey
         ,@c_door      = ORD.Door
         ,@c_deliveryNote = ORD.DeliveryNote
         ,@c_GetShipperKey = ORD.ShipperKey
   FROM ORDERS ORD WITH (NOLOCK)      
   WHERE ORD.Orderkey =   @c_OrderKey    
   
   --WL01 Start
   SELECT @c_EncryptPhoneNum = ISNULL(Short,'N')
   FROM CODELKUP (NOLOCK)
   WHERE LISTNAME = 'REPORTCFG' AND CODE = 'EncryptPhoneNumber'
   AND Storerkey = @c_StorerKey AND CODE2 = @c_GetShipperKey
   --WL01 End
    
   IF @b_debug = '1'      
   BEGIN       
      PRINT ' ORD address combine : ' + @c_ORDAdd + ' with orderkey : ' + @c_OrderKey      
   END    
      
   SET @c_CLong = ''    
     
   SELECT @c_consigneeFor = ISNULL(consigneeFor,'')  
   FROM Orders Ord WITH (NOLOCK)  
   JOIN Storer S WITH (NOLOCK) ON S.StorerKey=Ord.Shipperkey   
   WHERE Ord.Orderkey=@c_OrderKey  
  
   IF @b_debug='1'  
    BEGIN  
      Print ' consigneeFor : ' + @c_consigneeFor  
    END  

   --(WMS-551)
   SET @c_DeliveryRoute = '' 
   
   SELECT TOP 1 @c_DeliveryRoute = CLK.Long
   FROM CODELKUP AS CLK WITH (NOLOCK) 
   WHERE CLK.LISTNAME='SKLINES'
   AND CLK.Code = @c_State 
   AND CLK.Short = @c_GetShipperKey 
   AND CLK.StorerKey = @c_StorerKey     
            
   IF  @c_consigneeFor = 'A'   
   BEGIN  
      SELECT TOP 1 @c_cnotes = c.notes,
                  @c_short = C.short
      FROM Codelkup C WITH (NOLOCK)   
      WHERE C.short =  @c_GetShipperKey      
      AND C.Listname='COURIERMAP'     
      AND C.UDF01='ELABEL'   


      SELECT TOP 1    
         @c_CLong = C.Long      
      FROM Codelkup C WITH (NOLOCK)     
      WHERE C.short =  @c_GetShipperKey      
      AND   C.Listname='COURIERMAP'     
      AND   C.UDF01='ELABEL'        
      AND c.notes like N'%' + @c_City + '%'  
  
      IF @b_debug='1'  
         BEGIN  
         Print ' c_long : ' + @c_CLong  
      END  
  
      IF ISNULL(@c_CLong,'') = ''  
      BEGIN  
         SELECT TOP 1    
               @c_City = Ord.c_city  
         FROM ORDERS ORD WITH (NOLOCK) --ON ORD.ShipperKey = C.Short        
         WHERE ORD.Orderkey =  @c_OrderKey  
         AND  ORD.ShipperKey = @c_short                        
  
         SET @c_CLong = @c_City    
      END
          
      IF @b_debug='1'  
      BEGIN  
         Print ' c_city : ' + @c_City  
      END  
    END  
    ELSE  
    BEGIN    
       SELECT TOP 1    
            @c_CLong = C.Long      
       FROM Codelkup C WITH (NOLOCK)     
       WHERE C.Short=@c_GetShipperKey
       AND C.Listname='COURIERMAP'     
       AND C.UDF01='ELABEL'        
       AND c.Notes like N'%'+@c_State+'%' and c.Notes2 like N'%'+@c_City+'%' and c.Description like N'%'+@c_Address1+'%'  
       IF @b_debug='1'  
       BEGIN  
         Print ' c_long : ' +  @c_CLong
       END    
    END     
  
    SET @c_notes2 = ''   

    IF @c_StorerKey= '18389' AND @c_Door = '99'
    BEGIN
       SET @c_notes2= @c_deliveryNote  
    END
    ELSE
    BEGIN   
      SELECT TOP 1 @c_notes2 = C.Notes2         
      FROM   Codelkup C WITH (NOLOCK)   
        WHERE C.Short = @c_GetShipperKey                
          AND C.StorerKey = @c_StorerKey           
          AND C.Listname = 'WSCourier'
    END
 
   SET @c_UDF01 = ''   
   SELECT TOP 1   
          @c_UDF01 = C.UDF01  
   FROM   Codelkup C WITH (NOLOCK)   
   WHERE C.Short = @c_GetShipperKey               
     AND C.StorerKey = @c_StorerKey            
     AND C.Listname = 'WSCourier'  
 
    SET @c_GetCol55 = ''  
  
    SELECT TOP 1 @c_GetCol55 = C.Long  
    FROM Codelkup C WITH (NOLOCK)  
    WHERE C.listname='ELCOL55'  
    AND c.StorerKey = @c_StorerKey             
  
    IF @b_debug = '1'  
    BEGIN  
       PRINT ' Get Col55 : ' + @c_GetCol55   
    END           
    IF ISNULL(@c_GetCol55,'') = ''  
    BEGIN  
      SET @c_GetCol55 = 'Orders.IncoTerm'  
    END  
        
    SET @c_ExecStatements = ''  
    SET @c_ExecArguments = ''  
  
    SET @c_ExecStatements = N'SELECT @c_col55 =' + @c_GetCol55 + ' from orders (nolock) where orderkey=@c_OrderKey '  
  
    SET @c_ExecArguments = N'@c_GetCol55    NVARCHAR(80) '  
                          +',@c_OrderKey   NVARCHAR(30)'  
                          +',@c_col55      NVARCHAR(20) OUTPUT'  
  
     EXEC sp_ExecuteSql @c_ExecStatements   
                      , @c_ExecArguments  
                      , @c_GetCol55       
                      , @c_OrderKey  
                      , @c_col55 OUTPUT  
  
  
   IF @b_debug = '1'  
   BEGIN  
     PRINT ' Col55 : ' + @c_Col55   
   END    
  
   IF @b_debug = '1'  
   BEGIN  
       PRINT ' codelkup long : ' + @c_CLong + 'and notes2 : ' + @c_notes2 +   
       ' with orderkey : ' + @c_OrderKey  
   END
   
   SELECT TOP 1 @c_DischargePlace = ISNULL(DischargePlace,''),
                @c_DeliveryPlace  = ISNULL(DeliveryPlace,'')
   FROM ORDERS (NOLOCK)
   WHERE ORDERKEY = @c_OrderKey
     
   UPDATE #Result WITH (ROWLOCK)  
   SET    Col50     = @c_CLong,  
          Col51     = @c_notes2,   
          Col14     = @c_UDF01,   
          Col55     = @c_Col55,   
          Col59     = @c_DischargePlace,
          Col60     = @c_DeliveryPlace,
          Col32     = CASE WHEN @c_EncryptPhoneNum = 'Y' AND ISNUMERIC(RIGHT(RTRIM(Col32),4)) = 1   
                      THEN SUBSTRING(Col32,1,LEN(Col32) - 8) + '****' + RIGHT(RTRIM(Col32),4) ELSE Col32 END,
          Col33     = CASE WHEN @c_EncryptPhoneNum = 'Y' AND ISNUMERIC(RIGHT(RTRIM(Col33),4)) = 1 
                      THEN SUBSTRING(Col33,1,LEN(Col33) - 8) + '****' + RIGHT(RTRIM(Col33),4) ELSE Col33 END 
   WHERE  Col02     = @c_OrderKey        
      
   FETCH NEXT FROM CUR_UpdateRec INTO @c_OrderKey         
    
END -- While          
    
CLOSE CUR_UpdateRec            
DEALLOCATE CUR_UpdateRec        
      
    
   IF ISNULL(@c_Sparm4 ,0) <> 0   
   BEGIN    
       IF @c_Sparm4 = '1' 
       BEGIN  
           SELECT R.*  
           FROM   #Result R WITH (NOLOCK)   
           INNER  JOIN #PICK P WITH (NOLOCK)  
                       ON  P.Orderkey = R.Col02  
           WHERE  ISNULL(Col38, '') <> '' 
           AND P.TTLPICKQTY = 1  
           ORDER BY -- col59,  --(WMS-551)
             --       col60,  
                    col02 
       END    
       ELSE   
         
       /*CS03 Start*/     
       IF @c_Sparm4 > '1' AND @c_Sparm4 < '8'     --(CS29)
       BEGIN    
           SELECT R.*     
           FROM   #Result R WITH (NOLOCK)    
           INNER JOIN #PICK P WITH (NOLOCK)   
                      ON  P.Orderkey = R.Col02    
           WHERE  ISNULL(Col38 ,'') <> '' --CS06    
           AND    P.TTLPICKQTY > 1    
           ORDER BY col02    
       END    
       ELSE 
       /*CS29 start*/
       IF @c_Sparm4 = '8' 
       BEGIN  
         SELECT R.*     
           FROM   #Result R WITH (NOLOCK)    
           INNER JOIN #PICK P WITH (NOLOCK)   
                      ON  P.Orderkey = R.Col02    
           WHERE  ISNULL(Col38 ,'') <> '' --CS06    
           AND    P.TTLPICKQTY > 1 AND P.PickZone>1  
           ORDER BY P.PickZone,         --(CS17)  
                    P.picknotes,        --(CS16)  
                    col02--,  
                 --   col60 
       END
       ELSE
       /*CS29 End*/ 
       BEGIN  
       SELECT R.*     
           FROM   #Result R WITH (NOLOCK)    
           INNER JOIN #PICK P WITH (NOLOCK)   
                      ON  P.Orderkey = R.Col02    
           WHERE  ISNULL(Col38 ,'') <> ''    
           AND    P.TTLPICKQTY > 1 AND P.PickZone=1    
           ORDER BY P.PickZone,           
                    P.picknotes,         
                    col02--,  
                --    col60    
       END   
   END    
   ELSE    
   BEGIN  
    SELECT *  
    FROM   #Result WITH (NOLOCK)  
    WHERE  ISNULL(Col38, '') <> ''    
      --AND P.PickZone=1  
    ORDER BY  
           Col02  
   END                   
                 
EXIT_SP:    
  
   --SET @d_Trace_EndTime = GETDATE()  
   --SET @c_UserName = SUSER_SNAME()  
     
   --EXEC isp_InsertTraceInfo   
   --   @c_TraceCode = 'BARTENDER',  
   --   @c_TraceName = 'isp_BT_Bartender_Shipper_Label_BL',  
   --   @c_starttime = @d_Trace_StartTime,  
   --   @c_endtime = @d_Trace_EndTime,  
   --   @c_step1 = @c_UserName,  
   --   @c_step2 = '',  
   --   @c_step3 = '',  
   --   @c_step4 = '',  
   --   @c_step5 = '',  
   --   @c_col1 = @c_Sparm1,   
   --   @c_col2 = @c_Sparm2,  
   --   @c_col3 = @c_Sparm3,  
   --   @c_col4 = @c_Sparm4,  
   --   @c_col5 = @c_Sparm5,  
   --   @b_Success = 1,  
   --   @n_Err = 0,  
   --   @c_ErrMsg = ''              
                                    
END -- procedure

GO
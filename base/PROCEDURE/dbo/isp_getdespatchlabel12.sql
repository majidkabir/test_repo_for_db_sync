SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose:                                                                   */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2015-03-20 1.0  CSCHONG    Created (SOS335056)                             */                 
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_GetDespatchLabel12]                      
(  @c_Pickslipno         NVARCHAR(10),        
   @b_debug              INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                
   SET ANSI_WARNINGS OFF                      
                              
   DECLARE                  
      @c_PickheaderKey   NVARCHAR(18),                    
      @c_Orderkey        NVARCHAR(10),                         
      @n_ContainerQty    INT,     
      @c_ContainerType   NVARCHAR(20),   
      @n_seqno           INT, 
      @n_CurrentNo       INT,
      @c_OrdUDef03       NVARCHAR(20),
      @c_labelno         NVARCHAR(60),
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000)      
    
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
    SET @c_ContainerType = '' 
    SET @n_seqno = 1
    SET @c_labelno = ''
    SET @c_OrdUDef03 = ''
    SET @n_CurrentNo = 1              
              
    CREATE TABLE [#TempResult] (             
      [ID]           [INT] IDENTITY(1,1) NOT NULL,  
      [CurrentDate]  [NVARCHAR] (10) NULL,                        
      [DeliveryDate] [NVARCHAR] (10) NULL,              
      [OrdRoute]     [NVARCHAR] (10) NULL,              
      [ExternOrdKey] [NVARCHAR] (30) NULL,              
      [C_company]    [NVARCHAR] (45) NULL,              
      [C_Address]    [NVARCHAR] (90) NULL,              
      [C_Phone1]     [NVARCHAR] (18) NULL,              
      [Notes]        [NVARCHAR] (250) NULL,              
      [InterVehicle] [NVARCHAR] (80) NULL,              
      [CartonSeq]    INT NULL,              
      [TTLCarton]    INT NULL,              
      [barcode]      [NVARCHAR] (20) NULL          
     )            

   
   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                      
                        
      SELECT DISTINCT PH.orderkey,ORD.ContainerQty          
      FROM Pickheader PH WITH (NOLOCK)
      LEFT JOIN ORDERS ORD WITH (NOLOCK) ON PH.Orderkey=ORD.Orderkey
      WHERE Pickheaderkey =  @c_Pickslipno            
   

    OPEN CUR_RowNoLoop         

    FETCH NEXT FROM CUR_RowNoLoop INTO @c_Orderkey,@n_ContainerQty

    WHILE @@FETCH_STATUS <> -1               
    BEGIN  
   
    INSERT INTO #TempResult (CurrentDate,DeliveryDate,OrdRoute,ExternOrdKey,C_company,C_address,
                             c_phone1,notes,intervehicle,cartonseq,TTLCarton)
         
     SELECT DISTINCT CONVERT(NVARCHAR(10),GETDATE(),111),CONVERT(NVARCHAR(10),DeliveryDate,111),ORD.ROUTE,ORD.ExternOrderkey,
            C_Company,(RTRIM(ORD.C_ADDRESS1)+RTRIM(ORD.C_ADDRESS3)), 
            ORD.C_Phone1,ORD.Notes,(C1.CODE + C1.DESCRIPTION),@n_CurrentNo,@n_ContainerQty      
     FROM PICKHEADER PH WITH (NOLOCK)       
     FULL JOIN ORDERS ORD WITH (NOLOCK) ON ORD.ORDERKEY=PH.ORDERKEY
     -- LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.CODE = ORD.ContainerType AND C.LISTNAME=''CONTAINERT'''     
     LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.CODE=ORD.IntermodalVehicle AND C1.LISTNAME='VEHICLE'
     WHERE PH.Pickheaderkey =@c_Pickslipno   
              AND  ORD.Orderkey = @c_orderkey     
                
         IF @b_debug='1'                
         BEGIN                
            PRINT 'Orderkey = ' + @c_Orderkey + ' with total Carton = ' + convert(nvarchar(5),@n_ContainerQty)                  
         END          

         SELECT @c_Containertype = containertype,
                @c_OrdUDef03 = UserDefine03
         FROM ORDERS WITH (NOLOCK)
         WHERE OrderKey = @c_Orderkey

         IF @b_debug='1'                
         BEGIN                
            PRINT 'containerType = ' + @c_Containertype                    
         END 

        WHILE @n_CurrentNo <= @n_ContainerQty
          BEGIN
             
             IF @c_Containertype = 'C'
               BEGIN
                   SET @c_labelno = @c_OrdUDef03 + substring(@c_Pickslipno,4,7) + RIGHT('00'+ convert(varchar, @n_CurrentNo), 3) 
               END
               ELSE
               BEGIN
                   SET @c_labelno = substring(@c_Pickslipno,4,7) + RIGHT('00'+ convert(varchar, @n_CurrentNo), 3)        
               END
            IF @b_debug = '1'
            BEGIN
               PRINT 'labelno : ' + @c_labelno
               PRINT convert(nvarchar(5),@n_CurrentNo)
            END 

             IF @n_CurrentNo = 1
               BEGIN
                 UPDATE #TempResult
                 SET barcode= @c_labelno
                 WHERE ID = @n_CurrentNo  
               END
               ELSE
               BEGIN
                 INSERT INTO #TempResult (CurrentDate,DeliveryDate,OrdRoute,ExternOrdKey,C_company,C_address,
                             c_phone1,notes,intervehicle,cartonseq,TTLCarton,barcode) 
                  SELECT CurrentDate,DeliveryDate,OrdRoute,ExternOrdKey,C_company,C_address,
                             c_phone1,notes,intervehicle,@n_CurrentNo,TTLCarton,@c_labelno
                  FROM #TempResult
                  WHERE ID = 1
            
               END
               

             SET @n_CurrentNo = @n_CurrentNo + 1
          END 
         

       FETCH NEXT FROM CUR_RowNoLoop INTO @c_Orderkey,@n_ContainerQty
            
      END -- While                     
      CLOSE CUR_RowNoLoop                    
      DEALLOCATE CUR_RowNoLoop    
     
      SELECT CurrentDate,DeliveryDate,OrdRoute,ExternOrdKey,C_company,C_address,
             c_phone1,notes,intervehicle,cartonseq,TTLCarton,barcode
      FROM #TempResult (nolock)        
            
EXIT_SP:            
   
  
                                  
END -- procedure   



GO
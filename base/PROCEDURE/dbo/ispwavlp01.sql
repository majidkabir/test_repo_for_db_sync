SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  ispWAVLP01                                         */  
/* Creation Date:  02-Nov-2011                                          */  
/* Copyright: IDS                                                       */  
/* Written by:  NJOW                                                    */  
/*                                                                      */  
/* Purpose:  SOS#226952 Create load plan by wave & POCC                 */  
/*                                                                      */  
/* Input Parameters:  @c_WaveKey  - (WaveKey)                           */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* Return Status:  None                                                 */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:  RMC Generate Load Plan By Consignee                      */  
/*                                                                      */  
/* PVCS Version: 1.10                                                   */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver  Purposes                                   */  
/* 10-01-2012  ChewKP   1.1  Standardize ConsoOrderKey Mapping          */  
/*                           (ChewKP01)                                 */  
/* 21-02-2012  NJOW01   1.2  Re-run can combine to existing conso and   */  
/*                           load plan with same group                  */  
/* 23-03-2012  SHONG    1.3  Adding ConsoOrderLineNo into OrderDetail   */  
/* 27-03-2012  NJOW02   1.4  Change mapping from B_Fax2 to M_Fax1       */
/* 13-04-2012  SHONG    1.5  Change POCC Grouping for OrderDate         */
/* 22-04-2012  SHONG    1.6  Remove UpdateSource (BillFrom) from        */
/*                           Grouping                                   */
/* 25-04-2012  SHONG    1.7  Initial Variable                           */     
/* 01-05-2012  SHONG    1.8  Prevent Duplicate Conso Order LineNo       */ 
/* 02-05-2012  SHONG    1.9  Default SectionKey=Y (Last Order Flag)     */          
/* 07-11-2012  KHLim    1.10 DM integrity - Update EditDate  (KH01)     */
/* 27-06-2018  NJOW03   1.11 Fix - include NCHAR                        */
/* 28-Jan-2019  TLTING_ext 1.12 enlarge externorderkey field length     */
/************************************************************************/  
CREATE PROC [dbo].[ispWAVLP01]   
   @c_WaveKey NVARCHAR(10),  
   @b_Success int OUTPUT,   
   @n_err     int OUTPUT,   
   @c_errmsg  NVARCHAR(250) OUTPUT   
AS  
BEGIN  
  
   SET NOCOUNT ON   -- SQL 2005 Standard  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF      
  
   DECLARE @c_ConsigneeKey      NVARCHAR( 15)  
           ,@c_Priority          NVARCHAR( 10)  
           ,@c_C_Company         NVARCHAR( 45)  
           ,@c_OrderKey          NVARCHAR( 10)  
           ,@c_Facility          NVARCHAR( 5)  
           ,@c_ExternOrderKey    NVARCHAR( 50)  --tlting_ext  -- Purchase Order Number  
           ,@c_StorerKey         NVARCHAR( 15)  
           ,@c_Route             NVARCHAR( 10)  
           ,@c_debug             NVARCHAR( 1)  
           ,@c_loadkey           NVARCHAR( 10)  
           ,@n_continue          INT  
           ,@n_StartTranCnt      INT  
           ,@d_OrderDate         DATETIME  
           ,@d_Delivery_Date     DATETIME   
           ,@c_OrderType         NVARCHAR( 10)  
           ,@c_Door              NVARCHAR( 10)  
           ,@c_DeliveryPlace     NVARCHAR( 30)  
           ,@c_OrderStatus       NVARCHAR( 10)  
           ,@n_loadcount         INT  
           ,@n_TotWeight         FLOAT  
           ,@n_TotCube           FLOAT  
           ,@n_TotOrdLine        INT  
  
 DECLARE @c_ListName NVARCHAR(10)  
         ,@c_Code NVARCHAR(30) -- e.g. ORDERS01  
         ,@c_Description NVARCHAR(250)  
         ,@c_TableColumnName NVARCHAR(250)  -- e.g. ORDERS.Orderkey  
         ,@c_TableName NVARCHAR(30)  
         ,@c_ColumnName NVARCHAR(30)  
         ,@c_ColumnType NVARCHAR(10)  
         ,@c_SQLField NVARCHAR(2000)  
         ,@c_SQLWhere NVARCHAR(2000)  
         ,@c_SQLGroup NVARCHAR(2000)  
         ,@c_SQLDYN01 NVARCHAR(2000)  
         ,@c_SQLDYN02 nvarchar(2000)  
         ,@c_SQLDYN03 nvarchar(2000) --NJOW01  
         ,@c_Field01 NVARCHAR(60)  
         ,@c_Field02 NVARCHAR(60)  
         ,@c_Field03 NVARCHAR(60)  
         ,@c_Field04 NVARCHAR(60)  
         ,@c_Field05 NVARCHAR(60)  
         ,@c_Field06 NVARCHAR(60)  
         ,@c_Field07 NVARCHAR(60)  
         ,@c_Field08 NVARCHAR(60)  
         ,@c_Field09 NVARCHAR(60)  
         ,@c_Field10 NVARCHAR(60)  
         ,@n_cnt int  
         ,@c_FoundLoadkey NVARCHAR(10) --NJOW01  
         ,@c_FoundExternConsoOrderkey NVARCHAR(30) --NJOW01  
         ,@c_FoundConsoOrderkey NVARCHAR(30) --NJOW01  
        
  DECLARE @c_ExternConsoOrderkey NVARCHAR(30) -- Puchase Order Number  ExternOrderkey + '-CONS'  
          ,@c_IntermodalVehicle NVARCHAR(30) -- Customer Id  
          ,@c_InvoiceNo NVARCHAR(20) -- Host ERP System  
          ,@c_OrderDate NVARCHAR(10) -- Start Ship Date  
          ,@c_BillToKey NVARCHAR(15) -- Bill To  
          ,@c_MarkForKey NVARCHAR(15)  --Mark For  
          ,@c_UpdateSource NVARCHAR(10)  -- Bill From  
          ,@c_Userdefine02 NVARCHAR(20) -- SCAC Code / Carrier ID  
          ,@c_M_Phone2 NVARCHAR(18) -- Service Indicator  
          ,@c_PmtTerm NVARCHAR(10)  -- Freigh Terms  
          ,@c_M_Fax1 NVARCHAR(18)  -- Liz Claiborne Parcel Acct# / Primary Account number 
          ,@c_Issued NVARCHAR(1) -- TMS Order Status  
          ,@c_SlitShipEligible NVARCHAR(1) -- Split Shipment Eligible  
          ,@c_B_Phone2 NVARCHAR(18) -- Event Code  
          ,@c_NewStoreOpeFlag NVARCHAR(1) -- New Store Opening Flag  
          ,@c_Altsku NVARCHAR(20) -- Consolidation Code  
          ,@c_ConsoOrderKey NVARCHAR(30) -- System generate consolidation number -- (ChewKP01)  
          ,@c_ODUserdefine03 NVARCHAR(20) -- Building Floor Location  
  
 SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @n_loadcount = 0  
  
-------------------------- Wave Validation ------------------------------    
  IF NOT EXISTS(SELECT 1 FROM WaveDetail WITH (NOLOCK)   
                 WHERE WaveKey = @c_WaveKey)  
 BEGIN  
  SELECT @n_continue = 3  
  SELECT @n_err = 63501  
  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Orders being populated into WaveDetail. (ispWAVLP01)"  
  GOTO RETURN_SP  
 END  
   
-------------------------- Construct Load Plan Dynamic Grouping ------------------------------    
 IF @n_continue = 1 OR @n_continue = 2  
 BEGIN                    
   SELECT @c_listname = CODELIST.Listname  
   FROM WAVE (NOLOCK)   
   JOIN CODELIST (NOLOCK) ON WAVE.LoadPlanGroup = CODELIST.Listname AND CODELIST.ListGroup = 'WAVELPGROUP'  
   WHERE WAVE.Wavekey = @c_WaveKey  
     
   IF ISNULL(@c_ListName,'') = ''  
   BEGIN  
     SELECT @n_continue = 3  
     SELECT @n_err = 63502  
     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Empty/Invalid Load Plan Group Is Not Allowed. (LIST GROUP: WAVELPGROUP) (ispWAVLP01)"  
       GOTO RETURN_SP                      
     END  
       
     DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
        SELECT TOP 10 Code, Description, Long   
        FROM   CODELKUP WITH (NOLOCK)  
        WHERE  ListName = @c_ListName  
        ORDER BY Code  
       
     OPEN CUR_CODELKUP  
       
     FETCH NEXT FROM CUR_CODELKUP INTO @c_Code, @c_Description, @c_TableColumnName  
       
     SELECT @c_SQLField = '', @c_SQLWhere = '', @c_SQLGroup = '', @n_cnt = 0  
     WHILE @@FETCH_STATUS <> -1  
     BEGIN  
        SET @n_cnt = @n_cnt + 1   
        SET @c_TableName = LEFT(@c_TableColumnName, CharIndex('.', @c_TableColumnName) - 1)  
        SET @c_ColumnName = SUBSTRING(@c_TableColumnName,   
                            CharIndex('.', @c_TableColumnName) + 1, LEN(@c_TableColumnName) - CharIndex('.', @c_TableColumnName))  
  
        IF ISNULL(RTRIM(@c_TableName), '') <> 'ORDERS'   
        BEGIN  
        SELECT @n_continue = 3  
        SELECT @n_err = 63503  
        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Grouping Only Allow Refer To Orders Table's Fields. Invalid Table: "+RTRIM(@c_TableColumnName)+" (ispWAVLP01)"  
           GOTO RETURN_SP                      
        END   
       
        SET @c_ColumnType = ''  
        SELECT @c_ColumnType = DATA_TYPE   
        FROM   INFORMATION_SCHEMA.COLUMNS   
        WHERE  TABLE_NAME = @c_TableName  
        AND    COLUMN_NAME = @c_ColumnName  
       
        IF ISNULL(RTRIM(@c_ColumnType), '') = ''   
        BEGIN  
         SELECT @n_continue = 3  
         SELECT @n_err = 63504  
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Column Name: " + RTRIM(@c_TableColumnName)+ ". (ispWAVLP01)"  
           GOTO RETURN_SP                      
        END   
          
        IF @c_ColumnType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text')  
        BEGIN  
         SELECT @n_continue = 3  
         SELECT @n_err = 63505  
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Numeric/Text Column Type Is Not Allowed For Load Plan Grouping: " + RTRIM(@c_TableColumnName)+ ". (ispWAVLP01)"  
           GOTO RETURN_SP                      
        END   
       
        IF @c_ColumnType IN ('char', 'nvarchar', 'varchar','nchar') --NJOW03   
        BEGIN  
           SELECT @c_SQLField = @c_SQLField + ',' + RTRIM(@c_TableColumnName)  
           SELECT @c_SQLWhere = @c_SQLWhere + ' AND ' + RTRIM(@c_TableColumnName) + '=' +   
                  CASE WHEN @n_cnt = 1 THEN '@c_Field01'  
                       WHEN @n_cnt = 2 THEN '@c_Field02'  
                       WHEN @n_cnt = 3 THEN '@c_Field03'  
                       WHEN @n_cnt = 4 THEN '@c_Field04'  
                       WHEN @n_cnt = 5 THEN '@c_Field05'  
                       WHEN @n_cnt = 6 THEN '@c_Field06'  
                       WHEN @n_cnt = 7 THEN '@c_Field07'  
                       WHEN @n_cnt = 8 THEN '@c_Field08'  
                       WHEN @n_cnt = 9 THEN '@c_Field09'  
                       WHEN @n_cnt = 10 THEN '@c_Field10' END  
        END           
  
        IF @c_ColumnType IN ('datetime')   
        BEGIN  
           SELECT @c_SQLField = @c_SQLField + ', CONVERT(NVARCHAR(10),' + RTRIM(@c_TableColumnName) + ',112)'  
           SELECT @c_SQLWhere = @c_SQLWhere + ' AND CONVERT(NVARCHAR(10),' + RTRIM(@c_TableColumnName) + ',112)=' +   
                  CASE WHEN @n_cnt = 1 THEN '@c_Field01'  
                       WHEN @n_cnt = 2 THEN '@c_Field02'  
                       WHEN @n_cnt = 3 THEN '@c_Field03'  
                       WHEN @n_cnt = 4 THEN '@c_Field04'  
                       WHEN @n_cnt = 5 THEN '@c_Field05'  
                       WHEN @n_cnt = 6 THEN '@c_Field06'  
                       WHEN @n_cnt = 7 THEN '@c_Field07'  
                       WHEN @n_cnt = 8 THEN '@c_Field08'  
                       WHEN @n_cnt = 9 THEN '@c_Field09'  
                       WHEN @n_cnt = 10 THEN '@c_Field10' END  
        END  
                                      
        FETCH NEXT FROM CUR_CODELKUP INTO @c_Code, @c_Description, @c_TableColumnName  
     END   
     CLOSE CUR_CODELKUP  
     DEALLOCATE CUR_CODELKUP   
       
     SELECT @c_SQLGroup = @c_SQLField  
     WHILE @n_cnt < 10  
     BEGIN  
        SET @n_cnt = @n_cnt + 1  
         SELECT @c_SQLField = @c_SQLField + ','''''        
  
        SELECT @c_SQLWhere = @c_SQLWhere + ' AND ''''=' +   
               CASE WHEN @n_cnt = 1 THEN 'ISNULL(@c_Field01,'''')'  
                    WHEN @n_cnt = 2 THEN 'ISNULL(@c_Field02,'''')'  
                    WHEN @n_cnt = 3 THEN 'ISNULL(@c_Field03,'''')'  
                    WHEN @n_cnt = 4 THEN 'ISNULL(@c_Field04,'''')'  
                    WHEN @n_cnt = 5 THEN 'ISNULL(@c_Field05,'''')'  
                    WHEN @n_cnt = 6 THEN 'ISNULL(@c_Field06,'''')'  
                    WHEN @n_cnt = 7 THEN 'ISNULL(@c_Field07,'''')'  
                    WHEN @n_cnt = 8 THEN 'ISNULL(@c_Field08,'''')'  
                    WHEN @n_cnt = 9 THEN 'ISNULL(@c_Field09,'''')'  
                    WHEN @n_cnt = 10 THEN 'ISNULL(@c_Field10,'''')' END          
     END  
  END  
   
 BEGIN TRAN  
  
-------------------------- POCC - GROUP ORDERS ------------------------------    
  IF @n_continue = 1 OR @n_continue = 2  
  BEGIN     
     DECLARE cur_POCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
       SELECT RTRIM(MIN(ORDERS.Externorderkey))+  
                    CASE WHEN ISNULL(ORDERDETAIL.Altsku,'') = '' OR COUNT(DISTINCT ORDERS.Orderkey) = 1 THEN '' ELSE '-CONS' END AS Externorderkey,  
                ORDERS.IntermodalVehicle,  
                ORDERS.InvoiceNo,  
                CASE WHEN 
                     CONVERT(NVARCHAR(10), ORDERS.OrderDate,112)    <= CONVERT(NVARCHAR(10), GETDATE(),112) OR 
                     CONVERT(NVARCHAR(10), ORDERS.DeliveryDate,112) <= CONVERT(NVARCHAR(10), GETDATE(),112) 
                     THEN  CONVERT(NVARCHAR(10), GETDATE(),112) 
                     ELSE CONVERT(NVARCHAR(10), ORDERS.OrderDate,112) 
                END  AS OrderDate,  
                ORDERS.ConsigneeKey,  
                ORDERS.BillToKey,  
                ORDERS.MarkForKey,  
                --ORDERS.UpdateSource,  
                ORDERS.Userdefine02,  
                ORDERS.M_Phone2,  
                ORDERS.PmtTerm,  
                ORDERS.M_Fax1,  
                ORDERS.Issued,  
                SUBSTRING(ORDERS.B_Fax1,11,1) AS SplitShipEligible,  
                ORDERS.B_Phone2,  
                SUBSTRING(ORDERS.B_Fax1,10,1) AS NewStoreOpeFlag,  
                ISNULL(ORDERDETAIL.Altsku,'') AS Altsku,  
                ISNULL(ORDERDETAIL.UserDefine03,'') AS ODUserdefine03,  
                CASE WHEN ISNULL(ORDERDETAIL.Altsku,'') = '' THEN ORDERS.Orderkey ELSE '' END AS Orderkey                
         FROM WAVEDETAIL (NOLOCK)  
         JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey  
         JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey  
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey  
         AND ISNULL(ORDERDETAIL.ConsoOrderkey,'') = '' --NJOW01  
         GROUP BY ORDERS.IntermodalVehicle,  
                  ORDERS.InvoiceNo,  
                  CASE WHEN 
                     CONVERT(NVARCHAR(10), ORDERS.OrderDate,112)    <= CONVERT(NVARCHAR(10), GETDATE(),112) OR 
                     CONVERT(NVARCHAR(10), ORDERS.DeliveryDate,112) <= CONVERT(NVARCHAR(10), GETDATE(),112) 
                     THEN  CONVERT(NVARCHAR(10), GETDATE(),112) 
                     ELSE CONVERT(NVARCHAR(10), ORDERS.OrderDate,112) 
                  END ,  
                  ORDERS.ConsigneeKey,  
                  ORDERS.BillToKey,  
                  ORDERS.MarkForKey,  
                  --ORDERS.UpdateSource,  
                  ORDERS.Userdefine02,  
                  ORDERS.M_Phone2,  
                  ORDERS.PmtTerm,  
                  ORDERS.M_Fax1,  
                  ORDERS.Issued,  
                  SUBSTRING(ORDERS.B_Fax1,11,1),  
                  ORDERS.B_Phone2,  
                  SUBSTRING(ORDERS.B_Fax1,10,1),  
                  ISNULL(ORDERDETAIL.Altsku,''),  
                  ISNULL(ORDERDETAIL.UserDefine03,''),         
                  CASE WHEN ISNULL(ORDERDETAIL.Altsku,'') = '' THEN ORDERS.Orderkey ELSE '' END           
                    
         OPEN cur_POCC  
         FETCH NEXT FROM cur_POCC INTO @c_ExternConsoOrderKey, @c_IntermodalVehicle, @c_InvoiceNo, @c_OrderDate, @c_ConsigneeKey, @c_BillToKey,  
                                       @c_MarkForKey, --@c_UpdateSource, 
                                       @c_Userdefine02, @c_M_Phone2, @c_PmtTerm, @c_M_Fax1,  
                                       @c_Issued, @c_SlitShipEligible, @c_B_Phone2, @c_NewStoreOpeFlag, @c_Altsku, @c_ODUserdefine03, @c_Orderkey  
  
         WHILE @@FETCH_STATUS = 0  
         BEGIN            
            --NJOW01  
            SET @c_FoundConsoOrderkey = '' --(ung01)
            SET @c_FoundExternConsoOrderkey = '' --(ung01)
           
            SELECT TOP 1 @c_FoundConsoOrderkey = ORDERDETAIL.ConsoOrderkey,   
                         @c_FoundExternConsoOrderkey = ORDERDETAIL.ExternConsoOrderkey  
            FROM WAVEDETAIL (NOLOCK)  
            JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey  
            JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey  
            WHERE ISNULL(ORDERDETAIL.ConsoOrderkey,'') <> ''   
            AND ORDERS.IntermodalVehicle = @c_IntermodalVehicle  
            AND   ORDERS.InvoiceNo = @c_InvoiceNo  
            AND   CASE WHEN 
                     CONVERT(NVARCHAR(10), ORDERS.OrderDate,112)    <= CONVERT(NVARCHAR(10), GETDATE(),112) OR 
                     CONVERT(NVARCHAR(10), ORDERS.DeliveryDate,112) <= CONVERT(NVARCHAR(10), GETDATE(),112) 
                     THEN  CONVERT(NVARCHAR(10), GETDATE(),112) 
                     ELSE CONVERT(NVARCHAR(10), ORDERS.OrderDate,112) 
                  END  = @c_OrderDate  
            AND   ORDERS.ConsigneeKey = @c_ConsigneeKey  
            AND   ORDERS.BillToKey = @c_BillToKey  
            AND   ORDERS.MarkForKey = @c_MarkForKey  
            --AND   ORDERS.UpdateSource = @c_UpdateSource  
            AND   ORDERS.Userdefine02 = @c_Userdefine02  
            AND   ORDERS.M_Phone2 = @c_M_Phone2  
            AND   ORDERS.PmtTerm = @c_PmtTerm   
            AND   ORDERS.M_Fax1 = @c_M_Fax1  
            AND   ORDERS.Issued = @c_Issued  
            AND   SUBSTRING(ORDERS.B_Fax1,11,1) = @c_SlitShipEligible  
            AND   ORDERS.B_Phone2 = @c_B_Phone2  
            AND   SUBSTRING(ORDERS.B_Fax1,10,1) = @c_NewStoreOpeFlag  
            AND   ISNULL(ORDERDETAIL.Altsku,'') = @c_Altsku     
            AND   WAVEDETAIL.Wavekey = @c_wavekey  
            AND   ISNULL(ORDERDETAIL.UserDefine03,'') = @c_ODUserdefine03  
            AND   @c_Orderkey = ''                               
             
            IF ISNULL(@c_FoundConsoOrderkey,'') <> ''  --NJOW01  
            BEGIN  
               SELECT @c_ConsoOrderkey = @c_FoundConsoOrderkey  
               IF RIGHT(RTRIM(@c_FoundExternConsoOrderkey),5) <> '-CONS'  
               BEGIN  
                  SET @c_ExternConsoOrderkey = RTRIM(@c_FoundExternConsoOrderkey) + '-CONS'  
  
                  UPDATE ORDERDETAIL WITH (ROWLOCK)   
                       SET ORDERDETAIL.ExternConsoOrderKey = @c_ExternConsoOrderkey,  
                           ORDERDETAIL.EditDate    = GETDATE(), --KH01                       
                           ORDERDETAIL.TrafficCop = NULL  
                    FROM ORDERDETAIL  
                    WHERE ORDERDETAIL.ConsoOrderkey = @c_FoundConsoOrderkey  
        
               END                    
               ELSE  
                  SET @c_ExternConsoOrderkey = @c_FoundExternConsoOrderkey                                   
            END  
            ELSE  
            BEGIN  
              SELECT @b_success = 0  
               EXECUTE nspg_GetKey  
               'ConsoOrderKey',  
               10,  
               @c_ConsoOrderKey OUTPUT,  
               @b_success     OUTPUT,  
               @n_err         OUTPUT,  
               @c_errmsg      OUTPUT  
                 
             IF @b_success <> 1  
             BEGIN  
               SELECT @n_continue = 3  
                  GOTO RETURN_SP  
             END  
          END  
            
            UPDATE ORDERDETAIL WITH (ROWLOCK)   
            SET ORDERDETAIL.ExternConsoOrderKey = @c_ExternConsoOrderKey,  
                ORDERDETAIL.ConsoOrderKey = @c_ConsoOrderKey,  
                ORDERDETAIL.EditDate    = GETDATE(), --KH01                
                ORDERDETAIL.TrafficCop = NULL  
            FROM ORDERDETAIL  
            JOIN ORDERS (NOLOCK) ON ORDERDETAIL.Orderkey = ORDERS.Orderkey  
            JOIN WAVEDETAIL (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey  
            WHERE ORDERS.IntermodalVehicle = @c_IntermodalVehicle  
            AND   ORDERS.InvoiceNo = @c_InvoiceNo  
            AND   CASE WHEN 
                     CONVERT(NVARCHAR(10), ORDERS.OrderDate,112)    <= CONVERT(NVARCHAR(10), GETDATE(),112) OR 
                     CONVERT(NVARCHAR(10), ORDERS.DeliveryDate,112) <= CONVERT(NVARCHAR(10), GETDATE(),112) 
                     THEN  CONVERT(NVARCHAR(10), GETDATE(),112) 
                     ELSE CONVERT(NVARCHAR(10), ORDERS.OrderDate,112) 
                  END  = @c_OrderDate  
            AND   ORDERS.ConsigneeKey = @c_ConsigneeKey  
            AND   ORDERS.BillToKey = @c_BillToKey  
            AND   ORDERS.MarkForKey = @c_MarkForKey  
            --AND   ORDERS.UpdateSource = @c_UpdateSource  
            AND   ORDERS.Userdefine02 = @c_Userdefine02  
            AND   ORDERS.M_Phone2 = @c_M_Phone2  
            AND   ORDERS.PmtTerm = @c_PmtTerm   
            AND   ORDERS.M_Fax1 = @c_M_Fax1  
            AND   ORDERS.Issued = @c_Issued  
            AND   SUBSTRING(ORDERS.B_Fax1,11,1) = @c_SlitShipEligible  
            AND   ORDERS.B_Phone2 = @c_B_Phone2  
            AND   SUBSTRING(ORDERS.B_Fax1,10,1) = @c_NewStoreOpeFlag  
            AND   ISNULL(ORDERDETAIL.Altsku,'') = @c_Altsku     
            AND   WAVEDETAIL.Wavekey = @c_wavekey  
            AND   ISNULL(ORDERDETAIL.UserDefine03,'') = @c_ODUserdefine03  
            AND   (ORDERDETAIL.Orderkey = @c_Orderkey OR @c_Orderkey = '')  
              
            SELECT @n_err = @@ERROR  
  
          IF @n_err <> 0   
          BEGIN  
           SELECT @n_continue = 3  
           SELECT @n_err = 63506  
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update ORDERDETAIL Failed. (ispWAVLP01)"  
              GOTO RETURN_SP  
          END  
              
            FETCH NEXT FROM cur_POCC INTO @c_ExternConsoOrderKey, @c_IntermodalVehicle, @c_InvoiceNo, @c_OrderDate, @c_ConsigneeKey, @c_BillToKey,  
                                          @c_MarkForKey, --@c_UpdateSource, 
                                          @c_Userdefine02, @c_M_Phone2, @c_PmtTerm, @c_M_Fax1,  
                                          @c_Issued, @c_SlitShipEligible, @c_B_Phone2, @c_NewStoreOpeFlag, @c_Altsku, @c_ODUserdefine03, @c_Orderkey  
         END  
         CLOSE cur_POCC  
         DEALLOCATE cur_POCC           
           
  
         /*-------------------------------------------------------------------------------*/  
         /* Assign ConsoOrderLineNo to OrderDetail                                        */  
         /*-------------------------------------------------------------------------------*/  
         DECLARE @c_ConsoOrderLineNo   NVARCHAR(5),   
                 @c_OrderLineNumber    NVARCHAR(5),  
                 @n_ConsoLineNo        INT   
  
     
         DECLARE CUR_ConsoOrderLine CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT ORDERDETAIL.ConsoOrderKey, ORDERDETAIL.ORDERKEY, ORDERDETAIL.ORDERLINENUMBER    
         FROM WAVEDETAIL (NOLOCK)  
         JOIN ORDERDETAIL (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERDETAIL.Orderkey  
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey  
         AND (ORDERDETAIL.ConsoOrderLineNo IS NULL OR ORDERDETAIL.ConsoOrderLineNo = '')  
         ORDER BY ORDERDETAIL.ConsoOrderKey, ORDERDETAIL.ORDERKEY, ORDERDETAIL.ORDERLINENUMBER    
  
         OPEN CUR_ConsoOrderLine  
           
         FETCH NEXT FROM CUR_ConsoOrderLine INTO @c_ConsoOrderKey, @c_OrderKey, @c_OrderLineNumber   
           
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
         	SET @n_ConsoLineNo = 0
         	
            SELECT @n_ConsoLineNo = ISNULL(MAX(ConsoOrderLineNo),0)  
            FROM   ORDERDETAIL WITH (NOLOCK)  
            JOIN   WAVEDETAIL w WITH (NOLOCK) ON w.OrderKey = ORDERDETAIL.OrderKey 
            WHERE  ConsoOrderKey = @c_ConsoOrderKey  
            AND    ConsoOrderLineNo IS NOT NULL 
            AND    ConsoOrderLineNo <> ''
            AND    W.WaveKey = @c_WaveKey 
              
            SET @n_ConsoLineNo = @n_ConsoLineNo + 1  
              
            SET @c_ConsoOrderLineNo = RIGHT('0000' + CAST(@n_ConsoLineNo AS NVARCHAR(5)), 5)  

            IF EXISTS(SELECT 1 FROM ORDERDETAIL o WITH (NOLOCK) 
                      WHERE o.ConsoOrderKey = @c_ConsoOrderKey 
                      AND   o.ConsoOrderLineNo = @c_ConsoOrderLineNo)
            BEGIN  
              SELECT @n_continue = 3  
              SELECT @n_err = 63507  
              SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Duplicate Conso Order LineNo. (ispWAVLP01)"  
              GOTO RETURN_SP  
            END  
            
            UPDATE ORDERDETAIL   
               SET ConsoOrderLineNo = @c_ConsoOrderLineNo, TrafficCop = NULL  
                  ,EditDate    = GETDATE() --KH01               
            WHERE OrderKey = @c_OrderKey   
            AND   OrderLineNumber = @c_OrderLineNumber  
            
            FETCH NEXT FROM CUR_ConsoOrderLine INTO @c_ConsoOrderKey, @c_OrderKey, @c_OrderLineNumber  
         END  
         CLOSE CUR_ConsoOrderLine  
         DEALLOCATE CUR_ConsoOrderLine  
   
         IF EXISTS( SELECT 1 FROM ORDERDETAIL  o WITH (NOLOCK)  
                    JOIN   WAVEDETAIL w WITH (NOLOCK) ON w.OrderKey = O.OrderKey 
                    WHERE  W.WaveKey = @c_WaveKey
                    GROUP BY  o.ConsoOrderKey, o.ConsoOrderLineNo  
                    HAVING COUNT(DISTINCT o.OrderKey+o.OrderLineNumber) > 1)
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 63510  
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Found Duplicate Conso Order LineNo. (ispWAVLP01)"  
            GOTO RETURN_SP           	
         END                    
  
         /*  
         --Update Split conso order  
         SELECT ORDERS.Externorderkey, ORDERDETAIL.Orderkey  
         INTO #TMP_SPLITCONSOORDER          
         FROM WAVEDETAIL (NOLOCK)  
         JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey  
         JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey           
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey  
         --AND ISNULL(ORDERDETAIL.Altsku,'') <> ''                   
         GROUP BY ORDERS.Externorderkey, ORDERDETAIL.Orderkey  
         HAVING COUNT(DISTINCT ORDERDETAIL.ConsoOrderKey) > 1  
           
         UPDATE ORDERDETAIL WITH (ROWLOCK)   
         SET ORDERDETAIL.ExternConsoOrderKey = RTRIM(#TMP_SPLITCONSOORDER.Externorderkey) + '-CONS',  
             ORDERDETAIL.TrafficCop = NULL  
         FROM ORDERDETAIL  
         JOIN #TMP_SPLITCONSOORDER ON ORDERDETAIL.Orderkey = #TMP_SPLITCONSOORDER.Orderkey  
         WHERE ISNULL(ORDERDETAIL.Altsku,'') <> ''  
         */                   
   END  
  
-------------------------- CREATE LOAD PLAN ------------------------------     
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN        
      SELECT @c_SQLDYN01 = 'DECLARE cur_LPGroup CURSOR FAST_FORWARD READ_ONLY FOR '  
      + ' SELECT ORDERS.Storerkey ' + @c_SQLField   
      + ' FROM ORDERS WITH (NOLOCK) '  
      + ' JOIN WaveDetail WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '  
      +'  WHERE WD.WaveKey = N''' +  RTRIM(@c_WaveKey) +''''  
      + ' AND ISNULL(ORDERS.Loadkey,'''') = '''' '  
      + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '  
      + ' GROUP BY ORDERS.Storerkey ' + @c_SQLGroup  
      + ' ORDER BY ORDERS.Storerkey ' + @c_SQLGroup  
        
      EXEC (@c_SQLDYN01)  
  
      OPEN cur_LPGroup  
      FETCH NEXT FROM cur_LPGroup INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,   
                                       @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
  
        --NJOW01   
         SELECT @c_SQLDYN03 = ' SELECT @c_FoundLoadkey = MAX(ORDERS.Loadkey) '  
         + ' FROM ORDERS WITH (NOLOCK) '  
         + ' JOIN WaveDetail WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '  
         + ' WHERE  ORDERS.StorerKey = @c_StorerKey '   
         + ' AND WD.WaveKey = @c_WaveKey '  
         + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '  
         + ' AND ISNULL(ORDERS.Loadkey,'''') <> '''' '  
         + @c_SQLWhere  
          
        EXEC sp_executesql @c_SQLDYN03,   
             N'@c_Storerkey NVARCHAR(15), @c_Wavekey NVARCHAR(10), @c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60),@c_Field03 NVARCHAR(60),@c_Field04 NVARCHAR(60),  
               @c_Field05 NVARCHAR(60), @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60), @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60), @c_FoundLoadkey NVARCHAR(10) OUTPUT',   
             @c_Storerkey,  
             @c_Wavekey,                        
             @c_Field01,   
             @c_Field02,   
             @c_Field03,   
             @c_Field04,    
             @c_Field05,   
             @c_Field06,   
             @c_Field07,   
             @c_Field08,   
             @c_Field09,   
             @c_Field10,  
             @c_FoundLoadkey OUTPUT   
               
         IF ISNULL(@c_FoundLoadkey,'') <> '' --NJOW01  
            SET @c_loadkey = @c_FoundLoadkey            
         ELSE  
         BEGIN  
            SELECT @b_success = 0  
            EXECUTE nspg_GetKey  
               'LOADKEY',  
               10,  
               @c_loadkey     OUTPUT,  
               @b_success     OUTPUT,  
               @n_err         OUTPUT,  
               @c_errmsg      OUTPUT  
              
          IF @b_success <> 1  
          BEGIN  
            SELECT @n_continue = 3  
               GOTO RETURN_SP  
          END  
              
            SELECT @c_Facility = MAX(Facility)  
            FROM Orders WITH (NOLOCK)   
            WHERE Userdefine09 = @c_WaveKey  
               AND Storerkey = @c_StorerKey  
               AND Status NOT IN ('9','CANC')  
               AND ISNULL(Loadkey,'') = ''  
              
            -- Create loadplan          
            INSERT INTO LoadPlan (LoadKey, Facility)  
            VALUES (@c_loadkey, @c_Facility)  
              
          SELECT @n_err = @@ERROR  
              
          IF @n_err <> 0   
          BEGIN  
           SELECT @n_continue = 3  
           SELECT @n_err = 63507  
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into LOADPLAN Failed. (ispWAVLP01)"  
                 GOTO RETURN_SP  
          END  
       END  
         
       SELECT @n_loadcount = @n_loadcount + 1  
  
         -- Create loadplan detail  
     
         SELECT @c_SQLDYN02 = 'DECLARE cur_loadpland CURSOR FAST_FORWARD READ_ONLY FOR '  
         + ' SELECT ORDERS.OrderKey '  
         + ' FROM ORDERS WITH (NOLOCK) '  
         + ' JOIN WaveDetail WD WITH (NOLOCK) ON (ORDERS.OrderKey = WD.OrderKey) '  
         + ' WHERE  ORDERS.StorerKey = @c_StorerKey ' +  
         + ' AND WD.WaveKey = @c_WaveKey '  
         + ' AND ORDERS.Status NOT IN (''9'',''CANC'') '  
         + ' AND ISNULL(ORDERS.Loadkey,'''') = '''' '  
         + @c_SQLWhere  
         + ' ORDER BY ORDERS.OrderKey '  
  
        EXEC sp_executesql @c_SQLDYN02,   
             N'@c_Storerkey NVARCHAR(15), @c_Wavekey NVARCHAR(10), @c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60),@c_Field03 NVARCHAR(60),@c_Field04 NVARCHAR(60),  
               @c_Field05 NVARCHAR(60), @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60), @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60)',   
             @c_Storerkey,  
             @c_Wavekey,                        
             @c_Field01,   
             @c_Field02,   
             @c_Field03,   
             @c_Field04,   
             @c_Field05,   
             @c_Field06,   
             @c_Field07,   
             @c_Field08,   
             @c_Field09,   
             @c_Field10   
  
         OPEN cur_loadpland  
  
         FETCH NEXT FROM cur_loadpland INTO @c_OrderKey  
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
            IF (SELECT COUNT(1) FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @c_OrderKey) = 0  
            BEGIN  
               SELECT @d_OrderDate = O.OrderDate,   
                      @d_Delivery_Date = O.DeliveryDate,   
                      @c_OrderType = O.Type,  
                      @c_Door = O.Door,  
                      @c_Route = O.Route,  
                      @c_DeliveryPlace = O.DeliveryPlace,  
                      @c_OrderStatus = O.Status,  
                      @c_priority = O.Priority,  
                      @n_totweight = SUM(OD.OpenQty * SKU.StdGrossWgt),  
                      @n_totcube = SUM(OD.OpenQty * SKU.StdCube),  
                      @n_TotOrdLine = COUNT(DISTINCT OD.OrderLineNumber),  
                      @c_C_Company = O.C_Company,  
                      @c_ExternOrderkey = O.ExternOrderkey,  
                      @c_Consigneekey = O.Consigneekey  
               FROM Orders O WITH (NOLOCK)  
               JOIN Orderdetail OD WITH (NOLOCK) ON (O.Orderkey = OD.Orderkey)  
               JOIN SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku)  
               WHERE O.OrderKey = @c_OrderKey    
               GROUP BY O.OrderDate,   
                        O.DeliveryDate,   
                        O.Type,  
                        O.Door,  
                        O.Route,  
                        O.DeliveryPlace,  
                        O.Status,  
                        O.Priority,  
                        O.C_Company,  
                        O.ExternOrderkey,  
                        O.Consigneekey  
  
               EXEC isp_InsertLoadplanDetail   
                    @cLoadKey          = @c_LoadKey,  
                    @cFacility         = @c_Facility,              
                    @cOrderKey         = @c_OrderKey,             
                    @cConsigneeKey     = @c_Consigneekey,  
                    @cPrioriry         = @c_Priority,    
                    @dOrderDate        = @d_OrderDate,  
                    @dDelivery_Date    = @d_Delivery_Date,      
                    @cOrderType        = @c_OrderType,     
                    @cDoor             = @c_Door,              
                    @cRoute            = @c_Route,                          
                    @cDeliveryPlace    = @c_DeliveryPlace,  
                    @nStdGrossWgt      = @n_totweight,        
                    @nStdCube          = @n_totcube,           
                    @cExternOrderKey   = @c_ExternOrderKey,     
                    @cCustomerName     = @c_C_Company,  
                    @nTotOrderLines    = @n_TotOrdLine,      
                    @nNoOfCartons      = 0,  
                    @cOrderStatus      = '0',   
                    @b_Success         = @b_Success OUTPUT,   
                    @n_err             = @n_err     OUTPUT,  
                    @c_errmsg          = @c_errmsg  OUTPUT                 
     
               SELECT @n_err = @@ERROR  
     
               IF @n_err <> 0   
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @n_err = 63508  
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into LOADPLANDETAIL Failed. (ispWAVLP01)"  
                  GOTO RETURN_SP  
               END  
            END  
  
            FETCH NEXT FROM cur_loadpland INTO @c_OrderKey  
         END  
         CLOSE cur_loadpland  
         DEALLOCATE cur_loadpland  
  
         FETCH NEXT FROM cur_LPGroup INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,   
                         @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10  
      END  
      CLOSE cur_LPGroup  
      DEALLOCATE cur_LPGroup  
   END           
   
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN
   	-- Default Last Orders Flag to Y
   	UPDATE ORDERS WITH (ROWLOCK) 
   	   SET ORDERS.SectionKey = 'Y', ORDERS.TrafficCop = NULL 
            ,ORDERS.EditDate   = GETDATE() --KH01   	   
   	FROM ORDERS 
   	JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = ORDERS.OrderKey 
   	WHERE WD.WaveKey = @c_WaveKey 
   	
   END 
        
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF @n_loadcount > 0  
         SELECT @c_errmsg = RTRIM(CAST(@n_loadcount AS CHAR)) + ' Load Plan Generated'  
      ELSE  
         SELECT @c_errmsg = 'No Load Plan Generated'        
   END  
   
   
     
END  
  
RETURN_SP:  
  
IF @n_continue=3 -- Error Occured - Process And Return
BEGIN
    SELECT @b_success = 0   
    IF @@TRANCOUNT=1
       AND @@TRANCOUNT>@n_StartTranCnt
    BEGIN
        ROLLBACK TRAN
    END
    ELSE
    BEGIN
        WHILE @@TRANCOUNT>@n_StartTranCnt
        BEGIN
            COMMIT TRAN
        END
    END 
    EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispWAVLP01' 
    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
    RETURN
END
ELSE
BEGIN
    SELECT @b_success = 1   
    WHILE @@TRANCOUNT>@n_StartTranCnt
    BEGIN
        COMMIT TRAN
    END 
    RETURN
END

GO
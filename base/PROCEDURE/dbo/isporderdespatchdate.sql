SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Stored Procedure: ispOrderDespatchDate                               */      
/* Creation Date: 20-Aug-2010                                           */      
/* Copyright: IDS                                                       */      
/* Written by: LIM KAH HWEE                                             */      
/*                                                                      */      
/* Purpose: Update Despatch & Arrival date                              */      
/*                                                                      */      
/*                                                                      */      
/* Called By: BEJ - Update Despatch & Arrival Date                      */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date        Author Ver Purposes                                      */      
/* 2010-08-20  KHLim  1.0 initial revision                              */      
/* 2010-11-22  KHLim  1.1 Add TrafficCop = NULL                         */      
/* 2010-12-01  KHLim  1.2 Add Condition: IntermodalVehicle              */      
/*                        check if CODELKUP.Long = '', skip condition   */           
/* 2013-04-18  TLTING 1.3 Deadlock issue                                */  
/* 2014-04-07  TLTING 1.3 Bug fix                                       */
/************************************************************************/      
      
CREATE PROC [dbo].[ispOrderDespatchDate]            
AS      
BEGIN      
      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE @cSQL               nvarchar(MAX),      
           @cSQL2              nvarchar(MAX),      
           @cStorerKey         nvarchar(15),      
           @cType              nvarchar(10),      
           @cCompare           nvarchar(15),      
           @cOperator          char(2),      
           @cCutOff            char(5),      
           @nMinQty            int,      
           @nMaxQty            int,      
           @nProcess           int,      
           @cDatePart          char(1),      
           @cOrderKey          nvarchar(10),      
           @dOrderDate         datetime,      
           @dDeliveryDate      datetime,      
           @cIntermodalVehicle char(30),      
           @dAddDate           datetime,      
           @dUserDefine06      datetime,      
           @cOffDayList        nvarchar(7),      
           @cLeadTime          nvarchar(10),      
           @cFacility          nvarchar(5),      
           @cConsigneekey      nvarchar(15),      
           @cC_City            nvarchar(45),      
           @n_continue         int,      
           @n_starttcnt        int      
      
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT        
   -- tlting01  
   WHILE @@TRANCOUNT> 0  
      COMMIT TRAN  
   
   DECLARE Cur_StorerDD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT RTRIM(StorerKey), ISNULL(RTRIM(OrderType),''), RTRIM(CompareDate), Operator, CutOffTime, MinQty, MaxQty, ProcessTime, ProcessType      
   FROM   dbo.StorerSODefaultDate WITH (NOLOCK)       
   ORDER BY Priority      
      
   OPEN Cur_StorerDD      
      
   FETCH NEXT FROM Cur_StorerDD INTO @cStorerKey, @cType, @cCompare, @cOperator, @cCutOff, @nMinQty, @nMaxQty, @nProcess, @cDatePart      
      
   WHILE @@FETCH_STATUS <> -1      
   BEGIN      
      
    CREATE TABLE #tblOrder      
      (      
         OrderKey       nvarchar(10),      
         StorerKey      nvarchar(15),      
         OrderDate      datetime,      
         DeliveryDate   datetime,      
         ConsigneeKey   nvarchar(15),       
         C_City         nvarchar(45),      
         IntermodalVehicle char(30),      
         AddDate        datetime,      
         Facility       nvarchar(5),      
         UserDefine06   datetime      
      )      
      
--      PRINT @cType + ', ' + @cCompare + ', ' + @cOperator + ', ' + @cCutOff + ', ' + CAST(@nMinQty AS char(9)) + ', ' + CAST(@nMaxQty AS char(9)) + ', ' + CAST(@nProcess AS char(9)) + ', ' + @cDatePart      
      
   --   SET @cSQL = 'UPDATE ORDERS WITH (rowlock)       
   --      SET UserDefine06 = DateAdd(day, ' + CAST(@nProcess AS nvarchar(9)) + ', OrderDate)' +      
      SET @cSQL = 'INSERT INTO #tblOrder      
         SELECT RTRIM(OrderKey), RTRIM(StorerKey), OrderDate, DeliveryDate, RTRIM(ConsigneeKey), ISNULL(C_City,''''), RTRIM(IntermodalVehicle), AddDate, RTRIM(Facility),      
         CASE WHEN UserDefine06 IS NULL OR UserDefine06 = ''1/1/1900''      
            THEN DateAdd(' + CASE @cDatePart WHEN 'D' THEN 'dd' ELSE 'hh' END + ', ' + CAST(@nProcess AS nvarchar(9)) + ', ' + @cCompare + ')       
            ELSE UserDefine06 END AS UserDefine06       
         FROM ORDERS WITH (nolock) ' +      
         'WHERE (UserDefine06 IS NULL        OR DeliveryDate <= AddDate  OR   
                 UserDefine06 = ''1/1/1900'' OR DeliveryDate = ''1/1/1900'')   
            AND SOSTATUS not in (''9'',''CANC'')  AND STATUS not in (''9'',''CANC'')       
            AND AddDate <> ''1/1/1900'' AND OrderDate <> ''1/1/1900''      
            AND StorerKey = ''' + @cStorerKey + '''' +       
         CASE @cType WHEN '' THEN '' ELSE ' AND Type = ''' + @cType + '''' END      
      
      IF @cCutOff <> '00:00'      
      BEGIN      
         SET @cSQL = @cSQL +      
            ' AND CAST(REPLACE(STR(DATEPART(hour,   ' + @cCompare + '),2),'' '',''0'') AS char(2))+'':''+      
                  CAST(REPLACE(STR(DATEPART(minute, ' + @cCompare + '),2),'' '',''0'') AS char(2)) ' + @cOperator +       
                  '''' + @cCutOff + ''''      
      END      
      IF @nMinQty <> 0 OR @nMaxQty <> 0      
      BEGIN      
         SET @cSQL = @cSQL +      
            ' AND ( SELECT SUM(OriginalQty) FROM ORDERDETAIL WITH (nolock)       
               WHERE ORDERS.OrderKey = ORDERDETAIL.OrderKey ) BETWEEN ' + CAST(@nMinQty AS nvarchar(9)) +      
               ' AND ' + CAST(@nMaxQty AS nvarchar(9))      
      END      
      
--      PRINT @cSQL      
      
      EXEC(@cSQL)      
      
      DECLARE Cur_Order CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT *      
      FROM   #tblOrder WITH (NOLOCK)       
      
      OPEN Cur_Order      
      
      FETCH NEXT FROM Cur_Order INTO @cOrderKey, @cStorerKey, @dOrderDate, @dDeliveryDate, @cConsigneeKey, @cC_City, @cIntermodalVehicle, @dAddDate, @cFacility, @dUserDefine06      
      
      WHILE @@FETCH_STATUS <> -1      
      BEGIN      
         SELECT @cOffDayList = CASE WHEN Sun <> '0' THEN '1' ELSE '' END +       
                               CASE WHEN Mon <> '0' THEN '2' ELSE '' END +      
                               CASE WHEN Tue <> '0' THEN '3' ELSE '' END +      
                               CASE WHEN Wed <> '0' THEN '4' ELSE '' END +      
                               CASE WHEN Thu <> '0' THEN '5' ELSE '' END +      
                               CASE WHEN Fri <> '0' THEN '6' ELSE '' END +      
                               CASE WHEN Sat <> '0' THEN '7' ELSE '' END      
         FROM StorerSODefault WITH (nolock)       
         WHERE StorerKey = @cStorerKey                
      
         IF @cOffDayList <> '' AND LEN(@cOffDayList) < 7      
         BEGIN      
            WHILE CHARINDEX(CAST(DATEPART(dw, @dUserDefine06) AS NCHAR(1)),@cOffDayList) > 0       
            BEGIN      
               SET @dUserDefine06 = DateAdd(day, 1, @dUserDefine06)      
            END      
         END      
      
         IF @cDatePart = 'D'      
         BEGIN      
            SET @dUserDefine06 = DateAdd(second, -1, DateAdd(day, 1, CONVERT(char(11),@dUserDefine06,106)))      
         END      
      
         IF @dDeliveryDate <= @dAddDate OR @dDeliveryDate = '1/1/1900'      
--         IF DateDiff(minute,@dDeliveryDate, @dAddDate) = 0      
         BEGIN      
            SET @cLeadTime = ''      
      
            SET @cSQL = 'SELECT TOP 1 @cLeadTime = Short       
                        FROM CODELKUP WITH (nolock)       
                        WHERE LISTNAME = ''CityLdTime''      
                        AND CAST(Notes AS nvarchar(15)) = N''' + @cStorerKey + ''''      
                              
            DECLARE  @b_Success    int,      
                     @n_err        int,      
                     @c_authority  char(1),      
                     @c_errmsg     nvarchar(255)      
      
            EXECUTE dbo.nspGetRight       
               @cFacility, -- facility      
               @cStorerKey, -- Storerkey        
               NULL,         -- Sku        
               'CityLdTimeField',        -- Configkey        
               @b_success    output,        
               @c_authority  output,         
               @n_err        output,        
               @c_errmsg     output        
      
            IF @b_success <> 1        
            BEGIN        
               SELECT @n_continue = 3, @c_errmsg = 'ispOrderDespatchDate' + RTrim(@c_errmsg)        
            END        
            ELSE IF @c_authority = '1'      
            BEGIN      
               SET @cSQL = @cSQL + ' AND Description = ''' + @cC_City + ''''      
            END      
            ELSE IF @c_authority = '2'      
            BEGIN      
               SET @cSQL = @cSQL + ' AND Description = (SELECT City FROM STORER WITH (nolock) WHERE StorerKey = ''' + @cConsigneeKey + ''')'      
            END      
            ELSE IF @c_authority = '3'      
            BEGIN      
               SET @cSQL = @cSQL + ' AND Description = ''' + @cConsigneeKey + ''''      
            END      
      
            IF @cIntermodalVehicle = ''      
            BEGIN      
               SET @cSQL = @cSQL + ' AND CAST(Notes2 AS nvarchar(30)) = N''Road'''      
            END      
            ELSE      
            BEGIN      
               SET @cSQL = @cSQL + ' AND CAST(Notes2 AS nvarchar(30)) = N''' + @cIntermodalVehicle + ''''      
            END      
      
            SET @cSQL2 = @cSQL + ' AND Long = ''' + @cFacility + ''''      
      
--            PRINT @cSQL2      
            EXEC sp_executesql @cSQL2, N'@cLeadTime nvarchar(10) OUTPUT',  -- check with CODELKUP.Long = ORDERS.Facility      
                                        @cLeadTime OUTPUT         
            IF ISNUMERIC(@cLeadTime) = 1      
            BEGIN      
               SET @dDeliveryDate = DateAdd(day, CAST(@cLeadTime AS INT), @dUserDefine06)      
            END      
            ELSE      
            BEGIN      
               EXEC sp_executesql @cSQL, N'@cLeadTime nvarchar(10) OUTPUT',  -- check again without CODELKUP.Long (allow Long = '')      
                                           @cLeadTime OUTPUT         
               IF ISNUMERIC(@cLeadTime) = 1      
               BEGIN      
--                  PRINT @cLeadTime      
                  SET @dDeliveryDate = DateAdd(day, CAST(@cLeadTime AS INT), @dUserDefine06)      
               END      
               ELSE      
               BEGIN      
                  SET @dDeliveryDate = @dUserDefine06      
               END      
            END      
         END      
      
         BEGIN TRAN  
         UPDATE ORDERS WITH (rowlock)       
         SET UserDefine06 = @dUserDefine06,   
            DeliveryDate = @dDeliveryDate,   
            Editdate = getdate(),    -- tlting01  
            TrafficCop = NULL      
--         SELECT OrderKey, StorerKey, OrderDate, AddDate, @dUserDefine06 AS NewUserDefine06,       
--               DeliveryDate, @dDeliveryDate AS NewDeliveryDate      
--         FROM ORDERS WITH (nolock)       
         WHERE OrderKey = @cOrderKey      
         IF @@error <> 0      -- tlting01  
         BEGIN 
            ROLLBACK TRAN       
         END  
         ELSE  
         BEGIN   
            COMMIT TRAN   
         END  
      
         FETCH NEXT FROM Cur_Order INTO @cOrderKey, @cStorerKey, @dOrderDate, @dDeliveryDate, @cConsigneeKey, @cC_City, @cIntermodalVehicle, @dAddDate, @cFacility, @dUserDefine06      
      END      
      CLOSE Cur_Order      
      DEALLOCATE Cur_Order      
      
      DROP TABLE #tblOrder      
      
      FETCH NEXT FROM Cur_StorerDD INTO @cStorerKey, @cType, @cCompare, @cOperator, @cCutOff, @nMinQty, @nMaxQty, @nProcess, @cDatePart      
      
   END      
   CLOSE Cur_StorerDD      
   DEALLOCATE Cur_StorerDD      
     
   -- tlting01  
   WHILE @@TRANCOUNT <  @n_starttcnt  
      BEGIN TRAN  
  
   IF @n_continue=3  -- Error Occured - Process AND Return        
   BEGIN        
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt        
      BEGIN        
         ROLLBACK TRAN        
      END        
      ELSE        
      BEGIN        
         WHILE @@TRANCOUNT > @n_starttcnt        
         BEGIN        
            COMMIT TRAN        
         END        
      END        
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'ispOrderDespatchDate'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012        
      RETURN        
   END        
   ELSE        
   BEGIN        
      WHILE @@TRANCOUNT > @n_starttcnt        
      BEGIN        
         COMMIT TRAN        
      END        
      RETURN        
   END        
      
END -- procedure

GO
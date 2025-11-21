SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: nspLPRTSK10                                         */  
/* Creation Date: 27-JUL-2020                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-14196 - [CN] INDITEX_Release Pick Task                   */
/*                                                                       */  
/* Called By: Load                                                       */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/*************************************************************************/   

CREATE PROCEDURE [dbo].[nspLPRTSK10]      
  @c_LoadKey     NVARCHAR(10) 
 ,@n_err          int        OUTPUT  
 ,@c_errmsg       NVARCHAR(250)  OUTPUT  
 ,@c_Storerkey    NVARCHAR(15) = '' 
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE @n_continue int,    
            @n_starttcnt int,         -- Holds the current transaction count  
            @n_debug int,
            @b_success INT,  
            @n_cnt int
            
    SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
    SELECT  @n_debug = 0

    DECLARE  @c_Facility            NVARCHAR(5)
            ,@c_TaskType            NVARCHAR(10)            
            ,@c_SourceType          NVARCHAR(30)
            ,@c_Sku                 NVARCHAR(20)
            ,@c_Lot                 NVARCHAR(10)
            ,@c_FromLoc             NVARCHAR(10)
            ,@c_ID                  NVARCHAR(18)
            ,@n_Qty                 INT
            ,@c_UOM                 NVARCHAR(10)
            ,@n_UOMQty              INT
            ,@c_Toloc               NVARCHAR(10)                                    
            ,@c_Priority            NVARCHAR(10)            
            ,@c_PickMethod          NVARCHAR(10)            
            ,@c_LinkTaskToPick_SQL  NVARCHAR(4000)
            ,@c_SQL                 NVARCHAR(MAX)
            ,@n_PLTBalQty           INT
            ,@n_PLTQtyAllocated     INT
            ,@c_LocationType        NVARCHAR(10)
            ,@c_Consigneekey        NVARCHAR(15)
            ,@c_Company             NVARCHAR(45)
            ,@c_Orderkey            NVARCHAR(10)
            ,@c_InsertOrderkey      NVARCHAR(10)
            ,@c_BookToLoc           NVARCHAR(10)
            ,@n_OrderCnt            INT
            ,@c_TransitLOC          NVARCHAR(10)
            ,@c_LPUDF01             NVARCHAR(20)
            ,@c_LPUDF02             NVARCHAR(20)
            ,@n_cntDevPos           INT
            ,@n_CntConsigneekey     INT
            ,@c_Getloadkey          NVARCHAR(20) 
            ,@n_consigneekey        INT
            ,@n_devpos              INT    
                            
    SET @c_SourceType = 'nspLPRTS10'    
    SET @c_Priority = '8'

    SET @n_cntDevPos = 1
    SET @n_CntConsigneekey = 1

      
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN 
       IF EXISTS (SELECT 1 
                      FROM rdt.rdtSortAndPackLOC RSAP (NOLOCK)
                      WHERE RSAP.Loadkey = @c_Loadkey                   
                     )
       BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83000  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (nspLPRTSK10)'  
          GOTO RETURN_SP     
       END      
    END
       
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       SET @c_LPUDF01 = ''
       SET @c_LPUDF02 = ''

       SELECT @c_LPUDF01 = ISNULL(LP.Load_Userdef1,'')
             ,@c_LPUDF02 = ISNULL(LP.Load_Userdef2,'')
       FROM LOADPLAN LP WITH (NOLOCK)
       WHERE LP.LoadKey = @c_LoadKey
     
       IF ISNULL(@c_LPUDF01,'') = ''
       BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83010    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Loadplan Load_Userdef1 is blank not allow to released. (nspLPRTSK10)'      
         GOTO RETURN_SP 
       END
       ELSE
       BEGIN
           IF ISNULL(@c_LPUDF02,'') = ''
           BEGIN
  
             SET @c_LPUDF02 = @c_LPUDF01

              UPDATE LOADPLAN WITH (ROWLOCK)
              SET Load_Userdef2 = @c_LPUDF01
              WHERE loadkey = @c_LoadKey
                                                       
              SELECT @n_err = @@ERROR

              IF @n_err <> 0 
              BEGIN
                   SELECT @n_continue = 3  
                   SELECT @n_err = 83020    
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update loadplan Load_Userdef2 Fail. (nspLPRTSK10)'
                   GOTO RETURN_SP
             END 

          END

         SELECT @n_cntDevpos =  COUNT(DISTINCT DevicePosition)
         FROM dbo.DeviceProfile  WITH (NOLOCK) 
         WHERE DeviceType = 'STATION' AND Status='0' 
         AND DeviceID between @c_LPUDF01 and @c_LPUDF02
         GROUP BY DeviceID
		
         SELECT @n_cntconsigneekey =  COUNT(DISTINCT ConsigneeKey)
         FROM dbo.LoadPlanDetail WITH (NOLOCK) 
         WHERE LoadKey=@c_loadkey
         GROUP BY LoadKey

         IF @n_cntDevpos < @n_cntconsigneekey
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 83030    
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not enough loc. (nspLPRTSK10)'     
         END

      END   	
  END
          
    IF @@TRANCOUNT = 0
       BEGIN TRAN
               
     CREATE TABLE #TMPLPDCONSIGNEE 
     ( RowID          INT NOT NULL IDENTITY(1,1) Primary Key,
       Loadkey        NVARCHAR(20) NULL,
       Consigneekey   NVARCHAR(45) NULL
     --  LPUDF01        NVARCHAR(30) NULL
      )

      CREATE TABLE #TMPDEVPOS
     ( RowID           INT NOT NULL IDENTITY(1,1) Primary Key,
       Deviceid        NVARCHAR(20) NULL,
       DevicePosition  NVARCHAR(45) NULL
      )
                           
    IF @n_continue IN(1,2)
    BEGIN
    	 INSERT INTO #TMPLPDCONSIGNEE (Loadkey,Consigneekey)--,LPUDF01
       SELECT LPD.loadkey as loadkey,LPD.consigneekey as consigneekey--,LP.UserDefine01--,DevP.deviceposition
       FROM LOADPLAN LP WITH (NOLOCK)
       JOIN LoadPlanDetail LPD WITH (NOLOCK) ON LPD.loadkey = LP.loadkey
       WHERE LP.loadkey = @c_loadkey
       group by LPD.loadkey,LPD.consigneekey--,LP.UserDefine01
       Order by CAST(LPD.consigneekey as INT)


      INSERT INTO #TMPDEVPOS (Deviceid,DevicePosition)
      SELECT DeviceID as Deviceid,DevicePosition as devposition
      FROM dbo.DeviceProfile  WITH (NOLOCK) 
               WHERE DeviceType = 'STATION' AND Status='0' 
               AND DeviceID between @c_LPUDF01 and @c_LPUDF02
      group by DeviceID,DevicePosition
      Order by CAST(DevicePosition as INT)
 
     INSERT INTO RDT.rdtSortAndPackLOC (storerkey,loadkey,consigneekey,sortloc)
     SELECT @c_Storerkey,#TMPLPDCONSIGNEE.Loadkey,#TMPLPDCONSIGNEE.Consigneekey,#TMPDEVPOS.DevicePosition
     FROM #TMPLPDCONSIGNEE 
     JOIN #TMPDEVPOS ON #TMPDEVPOS.RowID = #TMPLPDCONSIGNEE.RowID
     ORDER BY #TMPLPDCONSIGNEE.RowID

    END
                    
                      
RETURN_SP:

    IF @n_continue=3  -- Error Occured - Process And Return  
    BEGIN  
       IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
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
       execute nsp_logerror @n_err, @c_errmsg, "nspLPRTSK10"  
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
 END --sp end

GO
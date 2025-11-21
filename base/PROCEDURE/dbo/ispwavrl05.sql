SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispWAVRL05                                                       */
/* Creation Date: 03-FEB-2021                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-15654 HK - Lululemon Relocation Project -               */ 
/*          Release Wave to WCS (Release to PTL)-                       */
/*          HK-UA-PTS Assign from wave                                  */
/*                                                                      */
/* Usage:   Storerconfig WaveReleaseToWCS_SP={SPName} to enable release */
/*          Wave to WCS option                                          */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 29-MAR-2021  CSCHONG  1.1  WMS-15654 revised logic (CS01)            */
/* 21-Jan-2022  NJOW01   1.2  WMS-18717 skip if wave.userdefine01<>''   */
/* 21-jAN-2022  NJOW01   1.2  DEVOPS combine script                     */
/************************************************************************/

CREATE PROC [dbo].[ispWAVRL05] 
   @c_WaveKey  NVARCHAR(10),
   @b_Success  INT OUTPUT,
   @n_err      INT OUTPUT,
   @c_errmsg   NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue       INT
         , @b_debug          INT
         , @n_StartTranCnt   INT
         , @c_Storerkey      NVARCHAR(15)
         , @c_Consigneekey   NVARCHAR(15)
         , @c_Loadkey        NVARCHAR(10)
         , @c_Orderkey       NVARCHAR(10)
         , @c_PickslipNo     NVARCHAR(10)
         , @c_Facility       NVARCHAR(5)
         , @c_DeviceId       NVARCHAR(20)
         , @c_IPAddress      NVARCHAR(40)
         , @c_PortNo         NVARCHAR(5)
         , @c_DevicePosition NVARCHAR(10)
         , @c_PTSLOC         NVARCHAR(10)
         , @c_BatchKey       NVARCHAR(20)
         , @c_CartonID       NVARCHAR(20)
         , @c_Userdefine04   NVARCHAR(20) --PTS zone (deviceprofile.deviceid / RDT.rdtPTLStationLog.station) (Wan01)
         , @c_Userdefine05   NVARCHAR(60) --PTS zone (deviceprofile.deviceid / RDT.rdtPTLStationLog.station) (Wan01)
         , @c_Userdefine08   NVARCHAR(20) --PTS zone (deviceprofile.deviceid / RDT.rdtPTLStationLog.station) (Wan01)
         , @c_Userdefine09   NVARCHAR(20) --method
         , @c_sectionkey     NVARCHAR(10) 
         , @c_PTLPKZoneReq   NVARCHAR( 1)   --CS01
         , @c_GetStorerkey   NVARCHAR(15)   --CS01
         , @n_cntptsloc      INT            --CS01
         , @c_Userdefine01   NVARCHAR(20)   --NJOW01

   IF @n_err = 1
      SET @b_debug = 1
      
   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = ''

   SET @c_PTLPKZoneReq = 0  --CS01
   SET @c_GetStorerkey = '' --CS01 
   

   --CS01 START

     CREATE TABLE #TMP_PTLLOC
     ( PTSLOC        NVARCHAR(20)
     )

   --CS01 END
   
   -----Get Wave Info-----
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN      
       SELECT TOP 1 @c_Userdefine05 = WAVE.Userdefine05, 
                    @c_Userdefine09 = WAVE.UserDefine09
                  , @c_Userdefine04 = ISNULL(RTRIM(WAVE.Userdefine04),'')        --(Wan01)
                  , @c_Userdefine08 = ISNULL(RTRIM(WAVE.Userdefine08),'')        --(Wan01)
                  , @c_GetStorerkey = ORDERS.Storerkey    --(CS01)   
                  , @c_Userdefine01 = WAVE.Userdefine01  --NJOW01                    
       FROM WAVE (NOLOCK)
       JOIN WAVEDETAIL (NOLOCK) ON WAVE.Wavekey = WAVEDETAIL.WaveKey
       JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey        
       WHERE WAVE.Wavekey = @c_Wavekey
                        
       IF @b_debug=1
          PRINT '@c_Userdefine05:' + RTRIM(@c_Userdefine05) + ' @c_Userdefine09:' + RTRIM(@c_Userdefine09) 
              + '@c_Userdefine04:' + RTRIM(@c_Userdefine04) + ' @c_Userdefine08:' + RTRIM(@c_Userdefine08) 

      --NJOW01
      IF ISNULL(@c_userdefine01,'') <> ''
         GOTO RETURN_SP

      --(Wan01) - START
      SET @c_Userdefine05 = ISNULL(RTRIM(@c_Userdefine05),'')

      IF @c_Userdefine04 <> '' 
      BEGIN
         SET @c_Userdefine05 = @c_Userdefine05 + ',' + @c_Userdefine04
      END 

      IF @c_Userdefine08 <> '' 
      BEGIN
         SET @c_Userdefine05 = @c_Userdefine05 + ',' + @c_Userdefine08
      END 
      
      IF LEFT(@c_Userdefine05,1) = ',' 
      BEGIN
         SET @c_Userdefine05 = SUBSTRING(@c_Userdefine05, 2, LEN(@c_Userdefine05) - 1)
      END 

       IF @b_debug=1
          PRINT 'Conbined @c_Userdefine05:' + RTRIM(@c_Userdefine05)  
      --(Wan01) - END                        
   END

    --CS01 START Get RDT.Storerconfig for PTLStationLogQueue
    SELECT TOP 1 @c_PTLPKZoneReq = ISNULL(svalue,0)
    FROM RDT.StorerConfig 
    WHERE ConfigKey = 'PTLStationLogQueue' 
    AND StorerKey=@c_GetStorerkey



    --CS01 END

   ------Validation--------
    IF @n_continue=1 or @n_continue=2  
    BEGIN          
       IF EXISTS(SELECT 1 FROM RDT.rdtPTLStationLog (NOLOCK) WHERE Wavekey = @c_Wavekey) 
             OR EXISTS(SELECT 1 FROM RDT.rdtPTLStationLogQueue (NOLOCK) WHERE Wavekey = @c_Wavekey)
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Failed. Wave Has Been Assigned to PTS Zone. (ispWAVRL05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
       END                

       --IF EXISTS(SELECT 1 FROM RDT.rdtPTLStationLog (NOLOCK) WHERE Station IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_Userdefine05)) AND ISNULL(Station,'') <> '') --NJOW01
       --BEGIN
       --  SELECT @n_continue = 3  
       --  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       --  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Failed. PTS Zone Is In Use. (ispWAVRL05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
       --  GOTO RETURN_SP
       --END                

       IF NOT EXISTS(SELECT 1 FROM DeviceProfile (NOLOCK) JOIN LOC (NOLOCK) ON DeviceProfile.Loc = LOC.Loc   
                     WHERE DeviceProfile.DeviceID IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_Userdefine05)) AND ISNULL(DeviceProfile.DeviceID,'') <> '' AND LOC.LocationCategory = 'PTS') --NJOW01
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Failed. PTS Zone(Userdefine05) Is Not Found. (ispWAVRL05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
       END                

       IF NOT EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) WHERE Code = @c_Userdefine09 AND Listname = 'PTLMETHOD')
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':  Release Failed. Invalid PLT Method(Userdefine09). (ispWAVRL05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
       END                

       IF EXISTS(SELECT 1 FROM ORDERS (NOLOCK) WHERE Userdefine09 = @c_Wavekey AND Status NOT IN('1','2','3','4','5'))
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Failed. Found Open or Shipped Orders In Wave. (ispWAVRL05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
       END                
              
       IF EXISTS(SELECT 1 FROM ORDERS O (NOLOCK) 
                 LEFT JOIN PICKHEADER PH (NOLOCK) ON O.Orderkey = PH.Orderkey
                 WHERE O.Userdefine09 = @c_Wavekey AND PH.Orderkey IS NULL)
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Failed. Missing Pickslip In Wave. (ispWAVRL05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
       END                      
       
       IF (SELECT COUNT(DISTINCT Orderkey) FROM WAVEDETAIL WD (NOLOCK) WHERE WD.Wavekey = @c_Wavekey) > 
          (SELECT COUNT(DISTINCT DeviceProfile.Loc) FROM DeviceProfile (NOLOCK) 
           JOIN LOC (NOLOCK) ON DeviceProfile.Loc = LOC.Loc
           WHERE DeviceProfile.DeviceID IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_Userdefine05)) AND ISNULL(DeviceProfile.DeviceID,'') <> '' AND LOC.LocationCategory = 'PTS') --NJOW01
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Failed. Insufficient PTS Device Location for the Wave. (ispWAVRL05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
       END                       
    END

   ------Assign Order to PTL-------   
   IF @n_continue=1 or @n_continue=2  
   BEGIN
      DECLARE cur_WAVEORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT O.Storerkey, O.Orderkey, O.Loadkey, O.Consigneekey, O.Facility, PH.PickHeaderkey,O.sectionkey
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
      JOIN PICKHEADER PH (NOLOCK) ON O.Orderkey = PH.Orderkey
      WHERE WD.Wavekey = @c_Wavekey
      GROUP BY O.Storerkey, O.Orderkey, O.Loadkey, O.Consigneekey, O.Facility, PH.PickHeaderkey,O.sectionkey 
      ORDER BY SUM(OD.QtyAllocated + OD.QtyPicked) DESC, O.Storerkey, O.Orderkey, O.Loadkey, O.Consigneekey

      OPEN cur_WAVEORDER  
      FETCH NEXT FROM cur_WAVEORDER INTO @c_Storerkey, @c_Orderkey, @c_Loadkey, @c_Consigneekey, @c_Facility, @c_Pickslipno,@c_sectionkey      
      
      SET @c_BatchKey = ''
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) 
      BEGIN                                 
         SELECT @c_DeviceId = '', @c_IPAddress = '', @c_PortNo = '', @c_DevicePosition = '', @c_PTSLOC = ''

         --CS01 START
 
          SET @n_cntptsloc = 0

          SELECT @n_cntptsloc = COUNT(1)
          FROM #TMP_PTLLOC

         --CS01 END

        IF @c_PTLPKZoneReq = 0
        BEGIN

            SELECT TOP 1 @c_DeviceId = DP.DeviceID, 
                         @c_IPAddress = DP.IPAddress, 
                         @c_PortNo = DP.PortNo, 
                         @c_DevicePosition = DP.DevicePosition, 
                         @c_PTSLOC = LOC.Loc
            FROM LOC (NOLOCK) 
            JOIN DEVICEPROFILE DP (NOLOCK) ON LOC.Loc = DP.Loc 
            --LEFT JOIN RDT.rdtPTLStationLog PTL (NOLOCK) ON LOC.Loc = PTL.Loc 
            WHERE DP.DeviceID IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_Userdefine05)) 
            AND ISNULL(DP.DeviceID,'') <> ''
            AND LOC.LocationCategory = 'PTS'
            --AND LOC.Facility = @c_Facility                                      
            --AND PTL.RowRef IS NULL 
            ORDER BY LOC.LogicalLocation, LOC.Loc
       END
       ELSE
       BEGIN
              IF @n_cntptsloc = 0
              BEGIN  
                    SELECT TOP 1 @c_DeviceId = DP.DeviceID, 
                         @c_IPAddress = DP.IPAddress, 
                         @c_PortNo = DP.PortNo, 
                         @c_DevicePosition = DP.DevicePosition, 
                         @c_PTSLOC = LOC.Loc
                     FROM LOC (NOLOCK) 
                     JOIN DEVICEPROFILE DP (NOLOCK) ON LOC.Loc = DP.Loc 
                     --LEFT JOIN RDT.rdtPTLStationLog PTL (NOLOCK) ON LOC.Loc = PTL.Loc 
                     WHERE DP.DeviceID IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_Userdefine05)) 
                     AND ISNULL(DP.DeviceID,'') <> ''
                     AND LOC.LocationCategory = 'PTS'
                     --AND LOC.Facility = @c_Facility                                      
                     --AND PTL.RowRef IS NULL 
                     ORDER BY LOC.LogicalLocation, LOC.Loc
             
              END
              ELSE
              BEGIN
                     SELECT TOP 1 @c_DeviceId = DP.DeviceID, 
                         @c_IPAddress = DP.IPAddress, 
                         @c_PortNo = DP.PortNo, 
                         @c_DevicePosition = DP.DevicePosition, 
                         @c_PTSLOC = LOC.Loc
                     FROM LOC (NOLOCK) 
                     JOIN DEVICEPROFILE DP (NOLOCK) ON LOC.Loc = DP.Loc 
                     --LEFT JOIN RDT.rdtPTLStationLog PTL (NOLOCK) ON LOC.Loc = PTL.Loc 
                     WHERE DP.DeviceID IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_Userdefine05)) 
                     AND ISNULL(DP.DeviceID,'') <> ''
                     AND LOC.LocationCategory = 'PTS'
                     AND LOC.Loc NOT IN (SELECT PTSloc FROM #TMP_PTLLOC)
                     --AND LOC.Facility = @c_Facility                                      
                     --AND PTL.RowRef IS NULL 
                     ORDER BY LOC.LogicalLocation, LOC.Loc    
     
              END
       END
       --CS01 END
         IF ISNULL(@c_PTSLOC,'')='' --AND @c_PTLPKZoneReq = 0
         BEGIN
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 82080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PTS Location Not Setup . (ispWAVRL05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END                   
         
         EXEC RDT.rdt_GenUCCLabelNo
           @c_StorerKey,  
           0,  
           @c_CartonID   OUTPUT,  
           'ENG',  
           @n_Err     OUTPUT,  
           @c_ErrMsg    OUTPUT 

         IF @n_err <> 0      
         BEGIN
            SELECT @n_continue = 3      
         END      
         
         IF ISNULL(@c_BatchKey,'') = ''
         BEGIN
            EXECUTE nspg_GetKey      
            'PTSBATCHNO',      
            10,      
            @c_BatchKey OUTPUT,         
            @b_success OUTPUT,      
            @n_err OUTPUT,      
            @c_errmsg OUTPUT      
            
            IF @b_success <> 1      
            BEGIN
               SELECT @n_continue = 3      
            END      
         END

         IF @b_debug=1
         BEGIN
            PRINT '@c_PTLPKZoneReq : ' +  @c_PTLPKZoneReq  
            PRINT '@c_Storerkey:' + RTRIM(@c_Storerkey) + ' @c_Orderkey:' + RTRIM(@c_Orderkey) + ' @c_Loadkey:' + RTRIM(@c_Loadkey)
            PRINT '@c_Consigneekey:' + RTRIM(@c_Consigneekey) + ' @c_Facility:' + RTRIM(@c_Facility) + ' @c_Pickslipno:' + RTRIM(@c_Pickslipno)
            PRINT '@c_DeviceId:' + RTRIM(@c_DeviceId) + ' @c_IPAddress:' + RTRIM(@c_IPAddress) + ' @c_PortNo:' + RTRIM(@c_PortNo)
            PRINT '@c_DevicePosition:' + RTRIM(@c_DevicePosition) + ' @c_PTSLOC:' + RTRIM(@c_PTSLOC) + ' @c_CartonID:' + RTRIM(@c_CartonID) + ' @c_BatchKey:' + RTRIM(@c_BatchKey)
         END
         
         IF @c_PTLPKZoneReq = 0    --CS01
         BEGIN 
         INSERT INTO RDT.rdtPTLStationLog (Station, IPAddress, Position, Loc, loadkey, Wavekey, Storerkey, Orderkey, 
                                           Consigneekey, Sourcekey, SourceType, Method, MaxTask, Pickslipno, BatchKey, CartonID)
                                   VALUES (@c_DeviceId, @c_IPAddress, @c_DevicePosition, @c_PTSLoc, @c_Loadkey, @c_Wavekey, @c_Storerkey, @c_Orderkey, 
                                           @c_Consigneekey, @c_Wavekey, 'ispWAVRL05', @c_Userdefine09, 0, @c_Pickslipno, @c_BatchKey, @c_CartonID)
         END --CS01 START
         ELSE
         BEGIN
         INSERT INTO RDT.rdtPTLStationLogQueue (Station, IPAddress, Position, Loc, loadkey, Wavekey, Storerkey, Orderkey, 
                                           Consigneekey, Sourcekey, SourceType, Method, MaxTask, Pickslipno, BatchKey, CartonID)
                                   VALUES (@c_DeviceId, @c_IPAddress, @c_DevicePosition, @c_PTSLoc, @c_Loadkey, @c_Wavekey, @c_Storerkey, @c_Orderkey, 
                                           @c_Consigneekey, @c_Wavekey, 'ispWAVRL05', @c_Userdefine09, 0, @c_Pickslipno, @c_BatchKey, @c_CartonID)
         END   --CS01 END
         
         SELECT @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RTD.rdtPTLStationLog or RDT.rdtPTLStationLogQueue Failed. (ispWAVRL05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END   

         --CS01 START
             IF @c_PTLPKZoneReq = 1
             BEGIN
                  INSERT INTO #TMP_PTLLOC
                  (
                      PTSLOC
                  )
                  VALUES
                  (@c_PTSLoc
                      )
             END 
         --CS01 END
         
         FETCH NEXT FROM cur_WAVEORDER INTO @c_Storerkey, @c_Orderkey, @c_Loadkey, @c_Consigneekey, @c_Facility, @c_Pickslipno ,@c_sectionkey 
      END
      CLOSE cur_WAVEORDER  
      DEALLOCATE cur_WAVEORDER                                   
   END    


   DROP TABLE #TMP_PTLLOC    --CS01
END -- Procedure

RETURN_SP:

IF (SELECT CURSOR_STATUS('LOCAL','cur_WAVEORDER')) >=0 
BEGIN
   CLOSE cur_WAVEORDER           
   DEALLOCATE cur_WAVEORDER      
END  

IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
   SELECT @b_success = 0
   IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
   BEGIN
      ROLLBACK TRAN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
   END
   execute nsp_logerror @n_err, @c_errmsg, 'ispWAVRL05'
   --RAISERROR @n_err @c_errmsg
   RETURN
END
ELSE
BEGIN
   SELECT @b_success = 1
   WHILE @@TRANCOUNT > @n_StartTranCnt
   BEGIN
      COMMIT TRAN
   END
   RETURN
END

GO
SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_WV_PVHAssignToLoc                          */
/* Creation Date: 31-Oct-2018                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-6872 PVH Update Pickdetail.ToLoc for RDT Fn760          */
/*          Sort and Pack                                               */
/*                                                                      */
/* Called By: Wave RCM configure at listname 'RCMConfig'                */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2019-01-03   TLTING01  1.1   Performance tune                        */
/* 2019-01-18   LZG       1.2   INC0550137 - Performance tune (ZG01)    */
/************************************************************************/

CREATE    PROCEDURE [dbo].[isp_RCM_WV_PVHAssignToLoc]
   @c_Wavekey  NVARCHAR(10),
   @b_success  int OUTPUT,
   @n_err      int OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30)=''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PTSLoc  			   NVARCHAR(10)
   	      ,@c_PickDetailKey    NVARCHAR(10)
   	      ,@c_CaseID 			   NVARCHAR(20)
   	      ,@c_LogicalLocation  NVARCHAR(10)
            ,@n_Cnt      		   INT
   	      ,@c_lastPTSLoc  		NVARCHAR(10)
   	      ,@c_PTSLoc_Fr	  	   NVARCHAR(10)
   	      ,@c_PTSLoc_To	  	   NVARCHAR(10)
   	      ,@c_Facility	  		NVARCHAR(5)
   	      ,@c_Storerkey		   NVARCHAR(15)
   	      ,@n_continue			INT
            ,@n_starttcnt		   INT
            ,@c_BillToKey		   NVARCHAR(15)
   	      ,@c_ConsigneeKey	   NVARCHAR(15)

   CREATE TABLE #Temp_Loc (ToLoc NVARCHAR(20))
   CREATE INDEX IDX_TOLOC ON #Temp_Loc (ToLoc) 
   
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0

   SET @n_Cnt = 0
   SET @c_lastPTSLoc = ''

   SELECT @c_PTSLoc_Fr = UserDefine02,
          @c_PTSLoc_To = UserDefine03
   FROM Wave (NoLock)
   WHERE WaveKey = @c_WaveKey

   IF ISNULL(@c_PTSLoc_Fr,'') = '' OR ISNULL(@c_PTSLoc_To,'') = ''
   BEGIN
      SET @n_Continue=3
      SET @n_err = 62030
      SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ 'Start or End Location is missing'
      GOTO ENDPROC
   END

--   IF @@TRANCOUNT = 0
--     BEGIN TRAN

   DECLARE CUR1 CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   	SELECT Distinct PD.CaseID, O.Facility, O.Storerkey, O.BillToKey, O.ConsigneeKey
   	FROM WAVEDETAIL WD (NOLOCK)
   	JOIN Orders O (nolock) ON WD.Orderkey = O.Orderkey
   	JOIN OrderDetail OD (nolock) ON O.OrderKey = OD.OrderKey
   	JOIN PickDetail PD (nolock) ON OD.OrderKey = PD.OrderKey and OD.OrderLineNumber = PD.OrderLineNumber
   	WHERE O.Status in ('3','5')
   		and PD.Status <= '4'
   		and PD.UOM <> '2'
   		and isnull(PD.ToLoc,'') = ''
   		and isnull(PD.CaseID,'') <> ''
   		and WD.Wavekey = @c_Wavekey
   	Order by O.BillToKey, O.ConsigneeKey, PD.CaseID

   OPEN CUR1

   WHILE 1=1 AND @n_continue IN(1,2)
   BEGIN
   	FETCH NEXT FROM CUR1 INTO @c_CaseID, @c_Facility, @c_Storerkey, @c_BillToKey, @c_ConsigneeKey

   	IF @@FETCH_STATUS = -1
   		BREAK

    TRUNCATE TABLE #Temp_Loc
    INSERT INTO #Temp_Loc (ToLoc) select DISTINCT  PD.ToLoc from PickDetail PD (nolock)    -- TLTING01 -- ZG01
    where PD.Storerkey = @c_Storerkey  and PD.Status <= '4'
    and isnull(PD.ToLoc,'') <> ''

   	IF @c_lastPTSLoc = ''
   		select top 1 @c_PTSLoc = Loc
   			From loc (nolock)
            LEFT JOIN #Temp_Loc (NOLOCK) as PDLoc on PDLoc.toloc = loc.loc
   			where Facility = @c_Facility and LocationCategory = 'PTS'
   			and   PDLoc.toloc is NULL
   			--	and Loc not in (select distinct PD.ToLoc from PickDetail PD (nolock)
   			--					where PD.Storerkey = @c_Storerkey and PD.Status <= '4'
   			--						and isnull(PD.ToLoc,'') <> '')
   				and Loc between @c_PTSLoc_Fr and @c_PTSLoc_To
   			order by loc.logicallocation, loc.loc
   	ELSE
   		select top 1 @c_PTSLoc = Loc
   			From loc (nolock)
            LEFT JOIN #Temp_Loc (NOLOCK) as PDLoc on PDLoc.toloc = loc.loc
   			where Facility = @c_Facility and LocationCategory = 'PTS'
   				and Loc > @c_lastPTSLoc
   				and   PDLoc.toloc is NULL
   				--and Loc not in (select distinct PD.ToLoc from PickDetail PD (nolock)
   				--				where PD.Storerkey = @c_Storerkey and PD.Status <= '4'
   				--					and isnull(PD.ToLoc,'') <> '' and PD.ToLoc > @c_lastPTSLoc)
   				and Loc between @c_PTSLoc_Fr and @c_PTSLoc_To
   			order by loc.logicallocation, loc.loc

   	If @c_PTSLoc = ''
   	BEGIN
          SET @n_Continue=3
          SET @n_err = 62030
          SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ 'No Available PTS Location'
   	END
   	ELSE IF @c_PTSLoc = @c_lastPTSLoc
   	BEGIN
          SET @n_Continue=3
          SET @n_err = 62030
          SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ 'No Available PTS Location'
    END
   	ELSE
   	BEGIN
   		 SET @c_lastPTSLoc = @c_PTSLoc

   		 DECLARE CUR2 CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   		 	SELECT   PD.PickDetailKey, loc.LogicalLocation
   		 	FROM Orders O (nolock)
   		 	JOIN OrderDetail OD (nolock) ON O.OrderKey = OD.OrderKey
   		 	JOIN PickDetail PD (nolock) ON  OD.OrderKey = PD.OrderKey and OD.OrderLineNumber = PD.OrderLineNumber
   		 	JOIN Loc loc (nolock) ON PD.loc = Loc.loc
   		 	WHERE O.Storerkey = @c_Storerkey
   		 		and O.Status in ('0','3')
   		 		and PD.Status <= '4'
   		 		and PD.UOM <> '2'
   		 		and isnull(PD.ToLoc,'') = ''
   		 		and PD.CaseID = @c_CaseID
   		 	GROUP BY PD.PickDetailKey, loc.LogicalLocation
   		 	Order by loc.LogicalLocation, PD.PickDetailKey

         BEGIN TRAN

   		 OPEN CUR2

   		 WHILE 1=1 AND @n_continue IN(1,2)
   		 BEGIN
   		 	FETCH NEXT FROM CUR2 INTO @c_PickDetailKey, @c_LogicalLocation

   		 	IF @@FETCH_STATUS = -1
   		 		BREAK

   		 	UPDATE PICKDETAIL
   		 		SET ToLoc = @c_PTSLoc,
   		 		   editwho = Suser_sname(),
   		 		   editdate = getdate()
   		 	WHERE  PickDetailKey = @c_PickDetailKey AND Status <= '4' AND ISNULL(ToLoc,'') = ''

   		 	SET @n_err = @@ERROR

   		 	IF @n_err <> 0
   		 	BEGIN
   		 		SELECT @n_Continue=3
   		 		SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 62030
   		 		SELECT @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ 'Update PICKDETAIL Failed.'
   		 					+ ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
   		 	END
   		 	ELSE
   		 	IF @@ROWCOUNT > 0
   		 		SET @n_Cnt = @n_Cnt + 1
   		 END
   		 CLOSE CUR2
   		 DEALLOCATE CUR2

         COMMIT TRAN
   	END
   END
   CLOSE CUR1
   DEALLOCATE CUR1

ENDPROC:
   DROP TABLE #Temp_Loc

   IF CURSOR_STATUS( 'LOCAL', 'CUR1') in (0 , 1)
   BEGIN
      CLOSE CUR1
      DEALLOCATE CUR1
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR2') in (0 , 1)
   BEGIN
      CLOSE CUR2
      DEALLOCATE CUR2
   END

   IF @n_continue=3  -- Error Occured - Process And Return
  BEGIN
     SELECT @b_success = 0
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
   execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_WV_PVHAssignToLoc'
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
     RETURN
  END
  ELSE
     BEGIN
        SELECT @b_success = 1
        WHILE @@TRANCOUNT > @n_starttcnt
        BEGIN
           COMMIT TRAN
        END
        RETURN
     END
END -- End PROC


GO